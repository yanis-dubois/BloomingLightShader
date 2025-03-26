/*******************************************/
/**************** ssr utils ****************/
/*******************************************/

// matrix row operations
vec4 addMatrixRows(mat4 matrix, int row1, int row2) {
    return vec4(
        matrix[0][row1] + matrix[0][row2],
        matrix[1][row1] + matrix[1][row2],
        matrix[2][row1] + matrix[2][row2],
        matrix[3][row1] + matrix[3][row2]
    );
}
vec4 subtractMatrixRows(mat4 matrix, int row1, int row2) {
    return vec4(
        matrix[0][row1] - matrix[0][row2],
        matrix[1][row1] - matrix[1][row2],
        matrix[2][row1] - matrix[2][row2],
        matrix[3][row1] - matrix[3][row2]
    );
}

// frustum planes extraction
void frustumPlane(out vec3 planes_normal[6], out vec3 planes_point[6]) {
    // extract frustum planes infos from projection matrix
    vec4 planesData[6] = vec4[](
        addMatrixRows(gbufferProjection, 3, 0), // left
        subtractMatrixRows(gbufferProjection, 3, 0), // right
        addMatrixRows(gbufferProjection, 3, 1), // bottom
        subtractMatrixRows(gbufferProjection, 3, 1), // top
        addMatrixRows(gbufferProjection, 3, 2), // near
        subtractMatrixRows(gbufferProjection, 3, 2) // far
    );
    // create planes from infos
    for (int i=0; i<6; ++i) {
        vec3 normal = - normalize(planesData[i].xyz);

        vec3 point = vec3(0.0);
        if (planesData[i].x != 0.0) {
            point.x = -planesData[i].w / planesData[i].x;
        } else if (planesData[i].y != 0.0) {
            point.y = -planesData[i].w / planesData[i].y;
        } else if (planesData[i].z != 0.0) {
            point.z = -planesData[i].w / planesData[i].z;
        }

        planes_normal[i] = normal;
        planes_point[i] = point;
    }
}

// find intersection between ray and frustum
vec3 rayFrustumIntersection(vec3 origin, vec3 direction, vec3 planes_normal[6], vec3 planes_point[6], out int index) {

    // get intersections
    bool hasIntersection[6];
    vec3 intersections[6];
    for (int i=0; i<6; ++i) {
        hasIntersection[i] = true;

        vec3 normal = planes_normal[i];
        vec3 point = planes_point[i];

        float denom = dot(normal, direction);
        // segment parallel to the plane
        if (denom < 1e-6) {
            hasIntersection[i] = false;
            continue;
        }

        // compute intersection
        float t = - (dot(normal, (origin - point))) / denom;
        if (t > 0.0) {
            intersections[i] = origin + (t - 1e-2) * direction;
        } else {
            hasIntersection[i] = false;
        }
    }

    // keep only intersections that are inside frustum
    for (int i=0; i<6; ++i) {
        if (!hasIntersection[i]) continue;

        bool isInside = true;
        for (int j=0; j<6; ++j) {
            if (dot(-planes_normal[j], intersections[i] - planes_point[j]) < 0.0) {
                isInside = false;
                break;
            }
        }

        if (isInside) {
            index = i;
            return intersections[i];
        }
    }

    return vec3(0.0);
}

// depth interpolation in view space
float perspectiveMix(float a, float b, float factor) {
    return 1.0 / ( (1.0/a) + (factor * ((1.0/b) - (1.0/a))) );
}

/*******************************************/
/******************* ssr *******************/
/*******************************************/

bool SSR_secondPass(sampler2D depthTexture, vec2 texelSpaceStartPosition, vec2 texelSpaceEndPosition, float startPositionDepth, float endPositionDepth, float lastPosition, float currentPosition, 
                    out vec2 screenSpaceFinalPosition) {
    float lastTopPosition = lastPosition, lastUnderPosition = currentPosition;
    float rayDepth, fragmentDepth, depthDifference;
    vec2 texelSpaceCurrentPosition, screenSpaceCurrentPosition;

    for (int i=0; i<4; ++i) {
        texelSpaceCurrentPosition = mix(texelSpaceStartPosition, texelSpaceEndPosition, currentPosition);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // depth at this uv coordinate
        fragmentDepth = - screenToView(
            screenSpaceCurrentPosition, 
            texture2D(depthTexture, screenSpaceCurrentPosition).r
        ).z;

        // determine actual depth
        rayDepth = - perspectiveMix(startPositionDepth, endPositionDepth, currentPosition);

        depthDifference = rayDepth - fragmentDepth;
        if (-REFLECTION_THICKNESS < depthDifference && depthDifference < REFLECTION_THICKNESS) {
            screenSpaceFinalPosition = screenSpaceCurrentPosition;
            return true;
        }

        // adjust position
        // if under depthmap 
        if (rayDepth > fragmentDepth) {
            lastUnderPosition = currentPosition;
            currentPosition = (lastTopPosition + currentPosition) / 2.0;
        }
        // if above depthmap 
        else {
            lastTopPosition = currentPosition;
            currentPosition = (lastUnderPosition + currentPosition) / 2.0;
        }
    }

    return false;
}

vec3 doReflection(sampler2D colorTexture, sampler2D lightAndMaterialTexture, sampler2D depthTexture, vec2 uv, float depth, vec3 color, vec3 normal, float ambientSkyLightIntensity, float smoothness, float reflectance) {

    // rough material have no reflection
    if (smoothness < 0.5) {
        return color;
    }

    // ------------------ step 1 : preparation ------------------ //

    // directions
    vec3 viewSpacePosition = screenToView(uv, depth);
    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 viewSpaceNormal = eyeToView(normal);

    // sample VNDF
    if (smoothness < 0.9) { // TODO: revoir ce threshold ?
        // sampling data
        float roughness = pow(1.0 - smoothness, 2.0);
        roughness *= roughness; 
        float zeta1 = pseudoRandom(uv + 0.913 * float(frameTimeCounter));
        float zeta2 = pseudoRandom(uv + 1.0 + 0.4351 * float(frameTimeCounter));

        // tbn - tangent to view 
        mat3 TBN = generateTBN(viewSpaceNormal); 
        // view direction from view to tangent space
        vec3 tangentSpaceViewDirection = transpose(TBN) * -viewDirection;
        // sample normal & convert to view
        vec3 sampledNormal = sampleGGXVNDF(tangentSpaceViewDirection, roughness, roughness, zeta1, zeta2);
        viewSpaceNormal = TBN * sampledNormal;
    }

    // directions and angles in view space
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));
    // reflected direction points : >0 = along the camera's line of sight / <0 = towards camera
    float reflectedDirectionDotZ = dot(reflectedDirection, vec3(0.0, 0.0, -1.0));

    // fresnel index
    float viewDirectionDotNormal = dot(-viewDirection, viewSpaceNormal);
    float fresnel = schlick(viewDirectionDotNormal, reflectance);
    #ifdef TRANSPARENT
        fresnel = 1.0 - pow(1.0 - fresnel, 2.0);
    #endif
    if (fresnel <= 0.001)
        return color;

    // background color
    float backgroundEmissivness; // useless here
    vec3 outdoorBackground = isEyeInWater==0 
        ? SRGBtoLinear(getSkyColor(viewToEye(reflectedDirection), true, backgroundEmissivness))
        : SRGBtoLinear(getWaterFogColor());
    if (normal.y < -0.1) outdoorBackground *= 0.5;
    vec3 indoorBackGround = vec3(0.0);
    vec3 backgroundColor = mix(indoorBackGround, outdoorBackground, ambientSkyLightIntensity);

    // lite version (only fresnel)
    vec3 reflection = backgroundColor;

    // only fresnel mod
    #if REFLECTION_TYPE == 1
        return mix(color, reflection, fresnel);
    #else

        // frustum planes
        vec3 planes_normal[6], planes_point[6];
        frustumPlane(planes_normal, planes_point);
        int frustumPlaneIndex = -1;

        // define start & end search positions
        vec3 viewSpaceStartPosition = viewSpacePosition;
        vec3 viewSpaceEndPosition = rayFrustumIntersection(viewSpaceStartPosition, reflectedDirection, planes_normal, planes_point, frustumPlaneIndex);
        float startPositionDepth = viewSpaceStartPosition.z;
        float endPositionDepth = viewSpaceEndPosition.z;
        vec2 screenSpaceStartPosition = viewToScreen(viewSpaceStartPosition).xy;
        vec2 screenSpaceEndPosition = viewToScreen(viewSpaceEndPosition).xy;
        vec2 texelSpaceStartPosition = screenToTexel(screenSpaceStartPosition);
        vec2 texelSpaceEndPosition = screenToTexel(screenSpaceEndPosition);
        vec2 delta = texelSpaceEndPosition.xy - texelSpaceStartPosition.xy;

        // determine the number of steps & their length
        float resolution = mix(0.1, REFLECTION_RESOLUTION, smoothness*smoothness*smoothness);
        resolution = clamp(resolution, 0.0, 1.0);
        float isXtheLargestDimmension = abs(delta.x) > abs(delta.y) ? 1.0 : 0.0;
        int stepsNumber = int(max(abs(delta.x), abs(delta.y)) * resolution);
        stepsNumber = min(stepsNumber, REFLECTION_MAX_STEPS);
        vec2 stepLength = delta / stepsNumber;

        // position used during the intersection search 
        // (factor of linear interpolation between start and end positions)
        float lastPosition = 0.0, currentPosition = 0.0;

        // initialize some variable
        vec2 seed = uv + 0.1 * frameTimeCounter;
        vec2 texelSpaceCurrentPosition = texelSpaceStartPosition;
        texelSpaceCurrentPosition += stepLength * pseudoRandom(seed);
        vec2 screenSpaceCurrentPosition = screenSpaceStartPosition;
        float rayDepth = startPositionDepth;
        float fragmentDepth = startPositionDepth;
        bool hitFirstPass = false, hitSecondPass = false;

        #if REFLECTION_TYPE == 2
            vec2 screenSpaceFinalPosition = screenSpaceEndPosition;
        #else

            // ------------------ step 2 : find reflection ------------------ //

            // ray marching 1 : find intersection
            for (int i=0; i<stepsNumber; ++i) {
                texelSpaceCurrentPosition += stepLength;
                screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);
                if (i == stepsNumber)
                    screenSpaceCurrentPosition = screenSpaceEndPosition;

                if (!isInRange(screenSpaceCurrentPosition, 0.0, 1.0)) {
                    break;
                }

                // depth at this uv coordinate
                fragmentDepth = - screenToView(
                    screenSpaceCurrentPosition, 
                    texture2D(depthTexture, screenSpaceCurrentPosition).r
                ).z;

                // percentage of progression on the line
                currentPosition = mix(
                    (texelSpaceCurrentPosition.y - texelSpaceStartPosition.y) / delta.y,
                    (texelSpaceCurrentPosition.x - texelSpaceStartPosition.x) / delta.x,
                    isXtheLargestDimmension
                );

                // determine actual depth
                if (startPositionDepth < endPositionDepth) {
                    rayDepth = - perspectiveMix(endPositionDepth, startPositionDepth, (1-currentPosition));
                }
                else {
                    rayDepth = - perspectiveMix(startPositionDepth, endPositionDepth, currentPosition);
                }

                // hit surface
                if (rayDepth > fragmentDepth) {
                    vec2 resultingPosition;
                    hitSecondPass = SSR_secondPass(
                        depthTexture, 
                        texelSpaceStartPosition, 
                        texelSpaceEndPosition, 
                        startPositionDepth, 
                        endPositionDepth, 
                        lastPosition, 
                        currentPosition, 
                        resultingPosition
                    );

                    if (hitSecondPass) {
                        screenSpaceCurrentPosition = resultingPosition;
                        break;
                    }  
                }

                lastPosition = currentPosition;
            }

            // ------------------ step 3 : adjustments and special cases ------------------ //

            // current position for 2nd pass hitted : end position for other
            vec2 screenSpaceFinalPosition = hitSecondPass 
                ? screenSpaceCurrentPosition 
                : screenSpaceEndPosition - texelToScreen(stepLength) * pseudoRandom(seed);
        #endif

        // evalutate if reflection point is valid or not
        bool isValid = true;

        float finalPositionDepth = texture2D(depthTexture, screenSpaceFinalPosition.xy).r;
        vec3 playerSpaceHitPosition = screenToPlayer(
            screenSpaceFinalPosition.xy, 
            finalPositionDepth
        );

        // avoid handheld object reflection
        if (distance(playerSpaceHitPosition, vec3(0.0)) < 0.5) {
            isValid = false;
        }

        if (hitSecondPass) {
            // restrict length of reflected ray that point towards the camera
            if (reflectedDirectionDotZ < 0.0) {
                if (distance(playerSpaceHitPosition, viewToPlayer(viewSpaceStartPosition)) > 2) {
                    isValid = false;
                }
            }
        }
        else {
            // valid only if hitted the far frustum plane
            if (frustumPlaneIndex != 5) {
                isValid = false;
            }
            if (finalPositionDepth < depth) {
                isValid = false;
            }
        }

        // get reflection
        if (isValid) {
            reflection = SRGBtoLinear(texture2D(colorTexture, screenSpaceFinalPosition).rgb);
            float emissivness = texture2D(lightAndMaterialTexture, screenSpaceFinalPosition).y;

            // underwater reflection
            if (isEyeInWater==1) {
                vec3 waterFogColor = SRGBtoLinear(getWaterFogColor());
                // underwater sky box
                if (distance(playerSpaceHitPosition, vec3(0.0)) > far) {
                    reflection = waterFogColor;
                    emissivness = 0.0;
                }
                // attenuate reflection
                else {
                    reflection = mix(reflection, waterFogColor * ambientSkyLightIntensity, 0.5);
                }
            }

            // sky box tweak
            if (finalPositionDepth == 1.0) {
                if (emissivness == 0.0) {
                    reflection = backgroundColor;
                }
            }
            else {
                vec3 worldSpacePosition = playerToWorld(playerSpaceHitPosition);
                float _;
                foggify(worldSpacePosition, backgroundColor, reflection, _);
            }

            // enhance reflection of emissive objects
            reflection += reflection * emissivness * 2.0;
        }

        // avoid abrupt transition between valid & non-valid reflection
        float fadeFactor = map(2.0 * distanceInf(vec2(0.5), screenSpaceFinalPosition), 0.8, 1.0, 0.0, 1.0);
        fadeFactor = pow(fadeFactor, 3.0);
        if (!isValid) fadeFactor = 1.0;
        reflection = mix(reflection, backgroundColor, fadeFactor);

        // debug
        // vec3 col[6] = vec3[6](
        //     vec3(1,0,0), // left : red
        //     vec3(0,1,0), // right : green
        //     vec3(0,0,1), // bottom : blue
        //     vec3(1,1,0), // top : yellow
        //     vec3(1,0,1), // near : magenta
        //     vec3(0,1,1) // far : cyan
        // );
        // reflection = col[frustumPlaneIndex];

        // return mix(color, reflection, 1);
        return mix(color, reflection, fresnel);
    #endif
}
