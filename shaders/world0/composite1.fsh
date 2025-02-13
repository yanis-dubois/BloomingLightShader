#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex3; // opaque material (type, smoothness, reflectance)
uniform sampler2D colortex4; // transparent color
uniform sampler2D colortex5; // transparent normal
uniform sampler2D colortex6; // transparent light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex7; // transparent material (type, smoothness, reflectance)
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth
uniform sampler2D depthtex2; // only opaque depth and no hand

in vec3 planes_normal[6];
in vec3 planes_point[6];

// attributes
in vec2 uv;

vec4 SSR_SecondPass(sampler2D colorTexture, sampler2D depthTexture, sampler2D lightTexture,
                    vec3 texelSpaceStartPosition, vec3 texelSpaceEndPosition, 
                    float startPositionDepth, float endPositionDepth,
                    float lastPosition, float currentPosition,
                    vec3 viewSpaceStartPosition, float reflectedDirectionDotZ, vec3 backgroundColor) {
    
    // no second pass
    if (SSR_STEPS <= 0) return vec4(0);

    // init
    vec3 texelSpaceCurrentPosition = vec3(0);
    vec3 screenSpaceCurrentPosition = vec3(0);
    float lastTopPosition = lastPosition, lastUnderPosition = currentPosition;
    float currentPositionDepth = 0;
    float actualPositionDepth = 0;
    float depthDifference = SSR_THICKNESS;
    bool hitSecondPass = false;

    // 2nd pass - binary search
    for (int i=0; i<SSR_STEPS; ++i) {
        texelSpaceCurrentPosition = mix(texelSpaceStartPosition, texelSpaceEndPosition, currentPosition);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // stop if outside frustum
        if (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x 
        || screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y) {
            break;
        }

        // depth at this uv coordinate
        actualPositionDepth = - screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthTexture, screenSpaceCurrentPosition.xy).r
        ).z;

        // determine actual depth
        currentPositionDepth = - perspectiveMix(startPositionDepth, endPositionDepth, currentPosition);

        float depthDifference = currentPositionDepth - actualPositionDepth;
        if (-SSR_THICKNESS < depthDifference && depthDifference < SSR_THICKNESS) {
            hitSecondPass = true;
            //break;
        }
        
        // adjust position
        // if under depthmap 
        if (currentPositionDepth > actualPositionDepth) {
            lastUnderPosition = currentPosition;
            currentPosition = (lastTopPosition + currentPosition) / 2;
        }
        // if above depthmap 
        else {
            lastTopPosition = currentPosition;
            currentPosition = (lastUnderPosition + currentPosition) / 2;
        }
    }

    float reflectionVisibility = hitSecondPass ? 1 : 0;

    // no hit
    if (reflectionVisibility <= alphaTestRef) {
        return vec4(0);
    }

    // restrict length of reflected ray that point towards the camera
    vec3 hitPosition = screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthTexture, screenSpaceCurrentPosition.xy).r
        );
    float dist = distance(viewToWorld(hitPosition), viewToWorld(viewSpaceStartPosition));
    if (reflectedDirectionDotZ < 0 && dist > 2) 
        return vec4(backgroundColor, reflectionVisibility);



    // 3rd pass - blur result by sampling pixels near hit on the line
    vec2 delta = (texelSpaceEndPosition - texelSpaceStartPosition).xy;
    float isXtheLargestDimmension = abs(delta.x) > abs(delta.y) ? 1 : 0;
    float stepsNumber = max(abs(delta.x), abs(delta.y)); // check which dimension has the longest to determine the number of steps
    vec2 stepLength = delta / stepsNumber;
    int sampleCount = int(1.0/SSR_RESOLUTION) * 4;
    sampleCount = 1;

    vec4 reflectionColor = vec4(0);
    texelSpaceCurrentPosition.xy -= stepLength * (sampleCount/2);
    for (int i=0; i<sampleCount; ++i) {
        texelSpaceCurrentPosition += vec3(stepLength, 1);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        vec4 color = texture2D(colorTexture, screenSpaceCurrentPosition.xy);
        // vec4 light = texture2D(lightTexture, screenSpaceCurrentPosition.xy);
        color.rgb = SRGBtoLinear(color.rgb);
        // color.rgb *= (light.z+1);

        reflectionColor += color;
    }
    reflectionColor /= sampleCount;

    return reflectionColor;
}

vec4 SSR(sampler2D colorTexture_opaque, sampler2D colorTexture_transparent, 
                 sampler2D depthTexture_opaque, sampler2D depthTexture_transparent, 
                 vec2 uv, float depth, vec3 normal, float smoothness, float reflectance, vec3 backgroundColor, float type) {

    // no reflections for perfectly rough surface
    if (smoothness <= 0.01 || isEyeInWater==1) return vec4(0);

    // directions and angles in view space
    vec3 viewSpacePosition = screenToView(uv, depth);
    vec3 viewSpaceNormal = normal;
    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));
    float viewDirectionDotNormal = dot(-viewDirection, viewSpaceNormal);
    float reflectedDirectionDotZ = dot(reflectedDirection, vec3(0,0,-1));

    // fresnel index
    float reflectionVisibility = schlick(viewDirectionDotNormal, reflectance);
    if (reflectionVisibility <= 0.001)
        return vec4(0);
    
    // lite version (only fresnel)
    vec4 reflection = vec4(backgroundColor, reflectionVisibility);
    if (SSR_TYPE == 1) return reflection;

    // define start and end search positions
    vec3 viewSpaceStartPosition = viewSpacePosition;
    vec3 viewSpaceEndPosition = rayFrustumIntersection(viewSpaceStartPosition, reflectedDirection, planes_normal, planes_point);
    float startPositionDepth = viewSpaceStartPosition.z;
    float endPositionDepth = viewSpaceEndPosition.z;
    vec3 screenSpaceStartPosition = viewToScreen(viewSpaceStartPosition);
    vec3 screenSpaceEndPosition = viewToScreen(viewSpaceEndPosition);
    vec3 texelSpaceStartPosition = screenToTexel(screenSpaceStartPosition);
    vec3 texelSpaceEndPosition = screenToTexel(screenSpaceEndPosition);

    // avoid start position = end position
    vec2 delta = texelSpaceEndPosition.xy - texelSpaceStartPosition.xy;
    if (delta.x == 0 && delta.y == 0) {
        return reflection;
    }

    // TODO: 
    // determine the step length
    // float resolution = mix(0.01, SSR_RESOLUTION, (smoothness*smoothness*smoothness) - (pseudoRandom(uv)*0.5));
    float resolution = mix(0.05, SSR_RESOLUTION, smoothness*smoothness*smoothness);
    resolution = clamp(resolution, 0, 1);
    float isXtheLargestDimmension = abs(delta.x) > abs(delta.y) ? 1 : 0;
    float stepsNumber = max(abs(delta.x), abs(delta.y)) * resolution; // check which dimension has the longest to determine the number of steps
    vec2 stepLength = delta / stepsNumber;

    // // TMP: some wild stuff
    // texelSpaceStartPosition.x += (1.0/resolution) - mod(texelSpaceStartPosition.x, (1.0/resolution));
    // texelSpaceStartPosition.y += (1.0/resolution) - mod(texelSpaceStartPosition.y, (1.0/resolution));

    // position used during the intersection search 
    // (factor of linear interpolation between start and end positions)
    float lastPosition = 0, currentPosition = 0;
    float lastPosition_transparent = 0, currentPosition_transparent = 0;

    // initialize some variable
    vec3 texelSpaceCurrentPosition = texelSpaceStartPosition;
    vec3 screenSpaceCurrentPosition = screenSpaceStartPosition;
    float currentPositionDepth = startPositionDepth;
    float actualPositionDepth_opaque = startPositionDepth;
    float actualPositionDepth_transparent = startPositionDepth;
    float depthDifference = SSR_THICKNESS;
    bool hitFirstPass_opaque = false, hitFirstPass_transparent = false, hitSecondPass = false;

    bool hasTMPhit = false;
    vec3 screenSpaceCurrentPositionTMP = screenSpaceStartPosition;
    float actualPositionDepth_opaqueTMP = actualPositionDepth_opaque;

    // 1st pass
    for (int i=0; i<int(stepsNumber); ++i) {
        texelSpaceCurrentPosition += vec3(stepLength, 0);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // depth at this uv coordinate
        actualPositionDepth_opaque = - screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthTexture_opaque, screenSpaceCurrentPosition.xy).r
        ).z;
        if (!hitFirstPass_transparent)
            actualPositionDepth_transparent = - screenToView(
                screenSpaceCurrentPosition.xy, 
                texture2D(depthTexture_transparent, screenSpaceCurrentPosition.xy).r
            ).z;
        
        // percentage of progression on the line
        currentPosition = mix(
            (texelSpaceCurrentPosition.y - texelSpaceStartPosition.y) / delta.y,
            (texelSpaceCurrentPosition.x - texelSpaceStartPosition.x) / delta.x,
            isXtheLargestDimmension
        );
        
        // determine actual depth
        if (startPositionDepth < endPositionDepth) {
            currentPositionDepth = - perspectiveMix(endPositionDepth, startPositionDepth, (1-currentPosition));
        }
        else {
            currentPositionDepth = - perspectiveMix(startPositionDepth, endPositionDepth, currentPosition);
        }
        if (currentPositionDepth < 0) {
            break;
        }

        // hit opaque surface
        if (actualPositionDepth_opaque < currentPositionDepth && currentPositionDepth < actualPositionDepth_opaque + SSR_THICKNESS) {
            hitFirstPass_opaque = true;
            break;
        }
        else if (actualPositionDepth_opaque < currentPositionDepth) {
            screenSpaceCurrentPositionTMP = screenSpaceCurrentPosition;
            actualPositionDepth_opaqueTMP = actualPositionDepth_opaque;
            hasTMPhit = true;
        }
        // hit transparent surface
        else if (!hitFirstPass_transparent && currentPositionDepth > actualPositionDepth_transparent) {
            hitFirstPass_transparent = true;
            lastPosition_transparent = lastPosition;
            currentPosition_transparent = currentPosition;
        }
        
        lastPosition = currentPosition;
    }
    if (!hitFirstPass_opaque && hasTMPhit) {
        screenSpaceCurrentPosition = screenSpaceCurrentPositionTMP;
        actualPositionDepth_opaque = actualPositionDepth_opaqueTMP;
        hitFirstPass_opaque = true;
    }

    // set default reflection to background color if ray goes towards camera 
    vec4 reflection_opaque = vec4(backgroundColor, reflectionVisibility);
    vec4 reflection_transparent = vec4(0);
    // to end position if it goes away from camera 
    if (reflectedDirectionDotZ > 0) {
        float endDepth = screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthTexture_opaque, screenSpaceEndPosition.xy).r
        ).z;

        if (startPositionDepth > endDepth) {

            //---------------------------//---------------------------//
            // vec3 texelPos = texelSpaceEndPosition;
            // stepsNumber = max(abs(delta.x), abs(delta.y)); // check which dimension has the longest to determine the number of steps
            // stepLength = delta / stepsNumber;
            // int sampleCount = int(1.0/SSR_RESOLUTION) * 2;

            // vec4 reflectionColor = vec4(0);
            // texelPos.xy -= stepLength * (sampleCount/2);
            // for (int i=0; i<sampleCount; ++i) {
            //     texelPos += vec3(stepLength, 0);
            //     screenSpaceCurrentPosition = texelToScreen(texelPos);

            //     vec4 color = texture2D(colorTexture_opaque, screenSpaceCurrentPosition.xy);
            //     vec4 light = texture2D(colortex2, screenSpaceCurrentPosition.xy);
            //     color.rgb = SRGBtoLinear(color.rgb) * (light.z+1);

            //     reflectionColor += color;
            // }
            // reflectionColor /= sampleCount;
            // reflection_opaque = reflectionColor;
            //---------------------------//---------------------------//

            reflection_opaque = texture2D(colorTexture_opaque, screenSpaceEndPosition.xy);
            reflection_opaque.rgb = SRGBtoLinear(reflection_opaque.rgb);

            // lighten sky emissive object
            if (endDepth < -far) {
                vec4 lightData = texture2D(colortex2, screenSpaceCurrentPosition.xy);
                reflection_opaque.rgb *= (1 + lightData.z*10);
            }

            reflection_transparent = texture2D(colorTexture_transparent, screenSpaceEndPosition.xy);
            reflection_transparent.rgb = SRGBtoLinear(reflection_transparent.rgb);
        }
    }

    // blended with fresnel & avoid abrupt transition
    reflection = vec4(mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a), reflectionVisibility);
    float fadeFactor = pow(2*distanceInf(vec2(0.5), screenSpaceCurrentPosition.xy), 5);
    reflection.rgb = mix(reflection.rgb, backgroundColor, fadeFactor);

    // no hit
    if (!hitFirstPass_opaque && !hitFirstPass_transparent) {
        // return vec4(1,0,0,1);
        return reflection;
    }

    //// TMP ////
    if (- startPositionDepth < actualPositionDepth_opaque) {
        reflection_transparent = texture2D(colorTexture_transparent, screenSpaceCurrentPosition.xy);
        reflection_transparent.rgb = SRGBtoLinear(reflection_transparent.rgb);
        reflection_opaque = texture2D(colorTexture_opaque, screenSpaceCurrentPosition.xy);
        reflection_opaque.rgb = SRGBtoLinear(reflection_opaque.rgb);
    }
    // set reflection to hitted position
    reflection.rgb = mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a);
    reflection.rgb = mix(reflection.rgb, backgroundColor, fadeFactor);
    return reflection;
    //// TMP ////

    // second pass for opaque and transparent blocks
    if (hitFirstPass_opaque)
        reflection_opaque = SSR_SecondPass(
            colorTexture_opaque, 
            depthTexture_opaque, colortex2,
            texelSpaceStartPosition, 
            texelSpaceEndPosition, 
            startPositionDepth,
            endPositionDepth,
            lastPosition, 
            currentPosition,
            viewSpaceStartPosition,
            reflectedDirectionDotZ,
            backgroundColor
        );
    if (hitFirstPass_transparent)
        reflection_transparent = SSR_SecondPass(
            colorTexture_transparent, 
            depthTexture_transparent, colortex6,
            texelSpaceStartPosition, 
            texelSpaceEndPosition, 
            startPositionDepth,
            endPositionDepth,
            lastPosition_transparent, 
            currentPosition_transparent,
            viewSpaceStartPosition,
            reflectedDirectionDotZ,
            backgroundColor
        );

    // no second hit
    if (reflection_opaque.a <= alphaTestRef && reflection_transparent.a <= alphaTestRef) {
        //return vec4(0,1,0,1);
        return reflection;
    }
        
    
    // set reflection to hitted position
    reflection.rgb = mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a);
    reflection.rgb = mix(reflection.rgb, backgroundColor, fadeFactor);
    return reflection;
}

// results
/* RENDERTARGETS: 0,1,2,4,5,6 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueBloomData;
layout(location = 2) out vec4 opaqueDOFData;
layout(location = 3) out vec4 transparentColorData;
layout(location = 4) out vec4 transparentBloomData;
layout(location = 5) out vec4 transparentDOFData;

void process(sampler2D albedoTexture, sampler2D normalTexture, sampler2D lightTexture, sampler2D materialTexture, sampler2D depthTexture,
            out vec4 colorData, out vec4 bloomData, out vec4 DOFData, bool isTransparent) {

    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(albedoTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);
    // normal
    vec4 normalData = texture2D(normalTexture, uv);
    vec3 normal = vec3(0);
    getNormalData(normalData, normal);
    // light
    vec4 lightData = texture2D(lightTexture, uv);
    float blockLightIntensity = 0, ambiantSkyLightIntensity = 0, emissivness = 0, ambient_occlusion = 0;
    getLightData(lightData, blockLightIntensity, ambiantSkyLightIntensity, emissivness, ambient_occlusion);
    // material
    vec4 materialData = texture2D(materialTexture, uv);
    float type = 0, smoothness = 0, reflectance = 0, subsurface = 0;
    getMaterialData(materialData, type, smoothness, reflectance, subsurface);
    // depth
    vec4 depthData = texture2D(depthTexture, uv);
    float depth = 0;
    getDepthData(depthData, depth);

    // basic and perfectly rough material have no reflection
    if (SSR_TYPE > 0 && !isBasic(type) && smoothness > 0.01) {
        // -- view space direction & normal -- //
        // view direction
        vec3 viewSpacePosition = screenToView(uv, depth);
        vec3 viewDirection = normalize(viewSpacePosition);
        // view space normal
        vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal);

        // -- sample VNDF -- //
        if (smoothness < 0.95) { // TODO: revoir ce threshold ?
            // sampling data
            float roughness = pow(1.0 - smoothness, 2.0);
            roughness *= roughness; 
            float zeta1 = pseudoRandom(uv + float(frameCounter)/720719.0);
            float zeta2 = pseudoRandom(uv + 1.0 + float(frameCounter)/720719.0);
            // tbn - tangent to view 
            mat3 TBN = generateTBN(viewSpaceNormal); 
            // view direction from view to tangent space
            vec3 tangentSpaceViewDirection = transpose(TBN) * -viewDirection;
            // sample normal & convert to view
            vec3 sampledNormal = sampleGGXVNDF(tangentSpaceViewDirection, roughness, roughness, zeta1, zeta2);
            viewSpaceNormal = TBN * sampledNormal;
        }
        
        // -- reflect ray -- //
        vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));
        float reflectedDirectionDotZ = dot(reflectedDirection, vec3(0,0,-1));
        
        // -- background color estimation -- // TODO: full bugé de nuit 
        // colors
        vec3 skyLightColor = getSkyLightColor();
        vec3 blockLightColor = vec3(1);
        skyLightColor = SRGBtoLinear(skyColor);
        blockLightColor = getBlockLightColor(blockLightIntensity, emissivness) * 0.5;
        // blend
        float lightAmount = max(blockLightIntensity, ambiantSkyLightIntensity);
        float lightSourceBlend = (blockLightIntensity + (lightAmount - ambiantSkyLightIntensity)) / (2*lightAmount);
        // estimate
        vec3 backgroundColor = mix(skyLightColor, blockLightColor, lightSourceBlend);
        backgroundColor = mix(vec3(0), backgroundColor, lightAmount);
        // background color goes to black if ray go towards camera
        vec3 towardReflectionColor = mix(vec3(0), backgroundColor, ambiantSkyLightIntensity);
        backgroundColor = mix(towardReflectionColor, backgroundColor, (reflectedDirectionDotZ+1)/2);

        // -- SSR -- //
        vec4 reflectionData = SSR(
            colortex0,
            colortex4,
            depthtex2,
            depthtex0,
            uv,
            depth,
            viewSpaceNormal,
            smoothness,
            reflectance,
            backgroundColor,
            type
        );
        vec3 reflectionColor = reflectionData.rgb;
        float reflectionVisibility = reflectionData.a;

        // -- apply reflection -- //
        // update transparency for transparent material
        if (isTransparent) {
            // add opacity as the reflection intensify
            transparency = max(transparency, reflectionVisibility);
        }
        // mix original color with reflection color
        colorData = vec4(mix(color, reflectionColor, reflectionVisibility), transparency);

        // colorData = reflectionData;
        colorData.rgb = linearToSRGB(colorData.rgb);
    }

    // -- prepare bloom texture -- //
    if (isTransparent) {
        bloomData = vec4(colorData.rgb * emissivness, transparency);
    }
    else {
        float lightness = getLightness(colorData.rgb);
        bloomData = vec4(colorData.rgb * max(pow(lightness, 5) * 0.5, emissivness), transparency);
    }

    // -- prepare depth of field -- //
    // focal plane distance
    float focusDepth = texture2D(depthtex1, vec2(0.5)).r;
    vec3 playerSpaceFocusPosition = screenToPlayer(vec2(0.5), focusDepth);
    float focusDistance = length(playerSpaceFocusPosition);
    focusDistance = min(focusDistance, far);
    // actual distance
    depth = texture2D(depthTexture, uv).r;
    vec3 playerSpacePosition = screenToPlayer(uv, depth);
    float linearDepth = length(playerSpacePosition);
    // blur amount
    float blurFactor = 0;
    if (focusDepth == 1.0) {
        blurFactor = depth < 1.0 ? 1.0 : 0.0;
    }
    else if (depth == 1.0) {
        blurFactor = 1.0;
    }
    else {
        float diff = abs(linearDepth - focusDistance);
        blurFactor = diff < DOF_FOCAL_PLANE_LENGTH ? 0.0 : 1.0;
        blurFactor *= map(diff, DOF_FOCAL_PLANE_LENGTH, 2*DOF_FOCAL_PLANE_LENGTH, 0.0, 1.0);
    }
    // write buffer
    DOFData = vec4(vec3(0.0), 1.0);
    if (blurFactor > 0.0) {
        // near plane
        if (linearDepth < focusDistance) {
            DOFData.rgb = vec3(blurFactor, 0.0, 0.0);
        }
        // far plane
        else if (linearDepth > focusDistance) {
            DOFData.rgb = vec3(0.0, blurFactor, 0.0);
        }
    }
}

/******************************************
******************* SSR *******************
******************************************/
void main() {
    process(colortex0, colortex1, colortex2, colortex3, depthtex1, opaqueColorData, opaqueBloomData, opaqueDOFData, false);
    process(colortex4, colortex5, colortex6, colortex7, depthtex0, transparentColorData, transparentBloomData, transparentDOFData, true);
}
