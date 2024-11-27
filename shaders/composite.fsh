#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/sample.glsl"
#include "/lib/shadow.glsl"

// textures
uniform sampler2D colortex0; // opaque albedo
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque light & type : x=block_light, y=sky_ambiant_light, z=material_type[0:basic,0.5:transparent,1:lit]
uniform sampler2D colortex3; // transparent albedo
uniform sampler2D colortex4; // transparent normal
uniform sampler2D colortex5; // transparent light & type
uniform sampler2D colortex6; // opaque type
uniform sampler2D colortex7; // opaque view space position
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

// attributes
in vec2 uv;

// functions
float linearizeDepth(float depth) {
    return 2.05 * (near * far) / (depth * (near - far) + far);
}

// TODO: be sure to normalize sample vec par rapport à l'espace view
float SSAO(vec2 uv, float depth, mat3 TBN) {
    // handle SSAO_SAMPLES<1 by skipping SSAO
    if (SSAO_SAMPLES<1)
        return 1;

    vec3 viewSpacePosition = screenToView(uv, depth);

    float occlusion = 0;
    float weigthts = 0;
    for (int i=0; i<SSAO_SAMPLES; ++i) {
        vec3 sampleTangentSpace = getSample(uv, i);
        vec3 sampleViewSpace = tangentToView(sampleTangentSpace, TBN);

        // offset and scale
        sampleViewSpace = sampleViewSpace * SSAO_RADIUS + viewSpacePosition;

        // convert from view to screen space
        vec3 sampleUV = viewToScreen(sampleViewSpace);

        // test if occluded
        float sampleDepth = texture2D(depthtex0, sampleUV.xy).r;
        if (sampleDepth + SSAO_BIAS > depth) {
            float weight = length(sampleTangentSpace);
            weigthts += weight;
            occlusion += mix(0, 1, weight/SSAO_RADIUS); // atenuate depending on sample radius
        }
    }
    if (weigthts > 0) {
        occlusion /= weigthts;
    }

    return occlusion;
}

// pas du tout opti mais fonctionne
vec4 SSR_naze(vec3 viewSpacePosition, vec3 viewSpaceNormal) {

    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));

    vec3 rayPos = viewSpacePosition;

    bool hit = false;
    vec2 UV = viewToScreen(viewSpacePosition).xy;
    for (int i=0; i<1000; ++i) {
        rayPos += reflectedDirection * 0.1;

        vec3 screenRay = viewToScreen(rayPos);
        UV = screenRay.xy;

        if (!isInRange(UV, 0, 1))
            break;

        float rayDepth = - rayPos.z;
        float mapDepth = - screenToView(UV, texture2D(depthtex1, UV).r).z;

        hit = rayDepth > mapDepth;
        if (hit) break;
    }

    if (!hit) return vec4(0);

    return vec4(texture2D(colortex0, UV).rgb, 1);
}

float perspectiveMix(float a, float b, float factor) {
    return 1 / ( (1/a) + (factor * ((1/b) - (1/a))) );
}

// TODO:
// - clip end pos
// - 
vec4 SSR(vec3 viewSpacePosition, vec3 viewSpaceNormal) {
    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));

    vec3 viewSpaceStartPosition = viewSpacePosition;
    vec3 viewSpaceEndPosition = viewSpacePosition + (reflectedDirection * far);

    // TODO: clamp inside frustum
    // vec3 clippedViewSpaceEndPosition = segmentFrustumIntersection(viewSpaceStartPosition, viewSpaceEndPosition);
    // return vec4(clippedViewSpaceEndPosition, 1);

    vec3 screenSpaceStartPosition = viewToScreen(viewSpaceStartPosition);
    vec3 screenSpaceEndPosition = viewToScreen(viewSpaceEndPosition);
    // todo: clamp in frustum !!!

    float startPositionDepth = viewSpaceStartPosition.z;
    float endPositionDepth = viewSpaceEndPosition.z;

    vec3 texelSpaceStartPosition = screenToTexel(screenSpaceStartPosition);
    vec3 texelSpaceEndPosition = screenToTexel(screenSpaceEndPosition);

    // avoid start position = end position
    vec2 delta = texelSpaceEndPosition.xy - texelSpaceStartPosition.xy;
    if (delta.x == 0 && delta.y == 0) {
        return vec4(0);
    }

    // determine the step length
    float isXtheLargestDimmension = abs(delta.x) > abs(delta.y) ? 1 : 0;
    float stepsNumber = max(abs(delta.x), abs(delta.y)) * clamp(SSR_RESOLUTION, 0, 1); // check which dimension has the longest to determine the number of steps
    vec2 stepLength = delta / stepsNumber;

    vec3 viewStep = (viewSpaceEndPosition - viewSpaceStartPosition) / stepsNumber;

    // position used during the intersection search 
    // (factor of linear interpolation between start and end positions)
    float lastPosition = 0, currentPosition = 0;

    // initialize some variable
    vec3 texelSpaceCurrentPosition = texelSpaceStartPosition;
    vec3 screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);
    float currentPositionDepth = 0;
    float actualPositionDepth = startPositionDepth;
    float depthDifference = SSR_THICKNESS;
    bool hitFirstPass = false, hitSecondPass = false;

    float debug=0, debug2=0, debug3=0;

    // 1st pass
    for (int i=0; i<int(stepsNumber+1); ++i) {
        texelSpaceCurrentPosition += vec3(stepLength, 1);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // stop if outside frustum
        if (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x 
        || screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y) {
            debug = 1;
            break;
        }

        // depth at this uv coordinate
        actualPositionDepth = - screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthtex1, screenSpaceCurrentPosition.xy).r
        ).z;
        
        // percentage of progression on the line
        currentPosition = mix(
            (texelSpaceCurrentPosition.y - texelSpaceStartPosition.y) / delta.y,
            (texelSpaceCurrentPosition.x - texelSpaceStartPosition.x) / delta.x,
            isXtheLargestDimmension
        );
        
        // determine actual depth
        currentPositionDepth = - perspectiveMix(startPositionDepth, endPositionDepth, currentPosition);
        if (currentPositionDepth < 0) {
            debug3 = 1;
            debug = 1;
            break;
        }

        // if hit
        if (currentPositionDepth > actualPositionDepth) {
            hitFirstPass = true;
            break;
        } 
        else {
            lastPosition = currentPosition;
        }
    }
    debug2 = hitFirstPass ? 1 : 0;

    //return vec4(debug2, debug, debug3, 1);

    if (!hitFirstPass)
        return vec4(0);
    
    float lastTopPosition = lastPosition, lastUnderPosition = currentPosition;
    debug=0; debug2=0; debug3=0;

    // 2nd pass
    for (int i=0; i<SSR_STEPS; ++i) {
        texelSpaceCurrentPosition = mix(texelSpaceStartPosition, texelSpaceEndPosition, currentPosition);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // stop if outside frustum
        if (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x 
        || screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y) {
            debug2=1;
            break;
        }

        // depth at this uv coordinate
        actualPositionDepth = - screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthtex1, screenSpaceCurrentPosition.xy).r
        ).z;

        // determine actual depth
        currentPositionDepth = - perspectiveMix(startPositionDepth, endPositionDepth, currentPosition);

        float depthDifference = currentPositionDepth - actualPositionDepth;
        if (-SSR_THICKNESS < depthDifference && depthDifference < SSR_THICKNESS) {
            hitSecondPass = true;
            break;
        }
        
        // adjust position
        // is under depthmap 
        if (currentPositionDepth > actualPositionDepth) {
            lastUnderPosition = currentPosition;
            currentPosition = (lastTopPosition + currentPosition) / 2;
        }
        // is above depthmap 
        else {
            lastTopPosition = currentPosition;
            currentPosition = (lastUnderPosition + currentPosition) / 2;
        }
    }

    // debug = hitSecondPass ? 1 : 0;
    // return vec4(debug, debug2, debug3, 1);

    float reflectionVisibility = hitSecondPass ? 1 : 0;
    // TODO: avoid calculus if no visibility
    // attenuate if reflected facing camera
    // reflectionVisibility *= (1 - max(dot(viewDirection, reflectedDirection), 0));
    // attenuate if ???
    // reflectionVisibility *= (1 - clamp(depthDifference / SSR_THICKNESS, 0, 1));
    // attenuate as it is near of max distance
    // reflectionVisibility *= (1 - clamp(length()));
    // set visibility to 0 if outside of camera frustum
    reflectionVisibility *= (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x ? 0 : 1)
                          * (screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y ? 0 : 1);
    
    //reflectionVisibility = 1;

    if (reflectionVisibility == 0)
        return vec4(0);

    vec3 reflectionColor = texture2D(colortex0, screenSpaceCurrentPosition.xy).rgb;
    return vec4(reflectionColor, reflectionVisibility);
}

vec4 SSR_tmp(vec3 viewSpacePosition, vec3 viewSpaceNormal) {
    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));

    vec3 viewSpaceStartPosition = viewSpacePosition;
    vec3 viewSpaceEndPosition = viewSpacePosition + (reflectedDirection * far);

    // TODO: clamp inside frustum
    vec3 clippedViewSpaceEndPosition = segmentFrustumIntersection(viewSpaceStartPosition, viewSpaceEndPosition);

    vec3 screenSpaceStartPosition = viewToScreen(viewSpaceStartPosition);
    vec3 screenSpaceEndPosition = viewToScreen(viewSpaceEndPosition);
    // todo: clamp in frustum !!!

    float startPositionDepth = viewSpaceStartPosition.z;
    float endPositionDepth = viewSpaceEndPosition.z;

    vec3 texelSpaceStartPosition = screenToTexel(screenSpaceStartPosition);
    vec3 texelSpaceEndPosition = screenToTexel(screenSpaceEndPosition);

    // avoid start position = end position
    vec2 delta = texelSpaceEndPosition.xy - texelSpaceStartPosition.xy;
    if (delta.x == 0 && delta.y == 0) {
        return vec4(0);
    }

    // determine the step length
    float isXtheLargestDimmension = abs(delta.x) > abs(delta.y) ? 1 : 0;
    float stepsNumber = max(abs(delta.x), abs(delta.y)) * clamp(SSR_RESOLUTION, 0, 1); // check which dimension has the longest to determine the number of steps
    vec2 stepLength = delta / stepsNumber;

    // position used during the intersection search 
    // (factor of linear interpolation between start and end positions)
    float lastPosition = 0, currentPosition = 0;

    // initialize some variable
    vec3 texelSpaceCurrentPosition = texelSpaceStartPosition;
    vec3 screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);
    float currentPositionDepth = 0;
    float actualPositionDepth = startPositionDepth;
    float depthDifference = SSR_THICKNESS;
    bool hitFirstPass = false, hitSecondPass = false;

    float debug=0, debug2=0, debug3=0;


    // currentPositionDepth = - (startPositionDepth * endPositionDepth) / mix(endPositionDepth, startPositionDepth, currentPosition);
    // actualPositionDepth = - screenToView(
    //     screenSpaceCurrentPosition.xy, 
    //     texture2D(depthtex1, screenSpaceCurrentPosition.xy).r
    // ).z;
    
    // return vec4(vec3(currentPositionDepth - actualPositionDepth) ,1);

    // 1st pass
    for (int i=0; i<int(stepsNumber+1); ++i) {
        texelSpaceCurrentPosition += vec3(stepLength, 1); //TODO add depth to the STEP
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // stop if outside frustum
        if (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x 
        || screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y) {
            debug = 1;
            break;
        }

        actualPositionDepth = - screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthtex1, screenSpaceCurrentPosition.xy).r
        ).z;
        
        // percentage of progression on the line
        currentPosition = mix(
            (texelSpaceCurrentPosition.y - texelSpaceStartPosition.y) / delta.y,
            (texelSpaceCurrentPosition.x - texelSpaceStartPosition.x) / delta.x,
            isXtheLargestDimmension
        );
        
        // determine actual depth
        float tmp = mix(startPositionDepth, endPositionDepth, currentPosition);
        // if (tmp == 0) {
        //     debug3 = 1;
        //     break;
        // }
        currentPositionDepth = - (startPositionDepth * endPositionDepth) / tmp; // division par zero!!!
        
        if (currentPositionDepth < 0) {
            debug3 = 1;
            debug = 1;
            break;
        }

        float depthDiff = currentPositionDepth - actualPositionDepth;

        // if hit
        if (SSR_THICKNESS < depthDiff && depthDiff < SSR_THICKNESS) {
        //if (currentPositionDepth > actualPositionDepth) {
            hitFirstPass = true;
            break;
        } 
        else {
            lastPosition = currentPosition;
        }
    }
    debug2 = hitFirstPass ? 1 : 0;

    // return vec4(debug2, debug, debug3, 1);
    // return vec4(screenSpaceCurrentPosition.xy, 0, 1);

    vec3 reflectionColor = vec3(0);
    if (true) {
        reflectionColor = texture2D(colortex0, screenSpaceCurrentPosition.xy).rgb;
    }
    return vec4(vec3(reflectionColor), 1);

    // ??
    currentPosition = lastPosition + ((currentPosition-lastPosition) / 2);

    if (!hitFirstPass)
        return vec4(0);

    // 2nd pass
    for (int i=0; i<SSR_STEPS; ++i) {
        texelSpaceCurrentPosition = mix(texelSpaceStartPosition, texelSpaceEndPosition, currentPosition);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // stop if outside frustum
        if (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x 
        || screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y) {
            break;
        }

        actualPositionDepth = texture2D(depthtex1, screenSpaceCurrentPosition.xy).r;

        // determine actual depth
        float tmp = mix(startPositionDepth, endPositionDepth, currentPosition);
        // if (tmp == 0) {
        //     debug3 = 1;
        //     break;
        // }
        currentPositionDepth = (startPositionDepth * endPositionDepth) / tmp;

        depthDifference = currentPositionDepth - actualPositionDepth;

        if (0 < depthDifference && depthDifference < SSR_THICKNESS) {
            hitSecondPass = true;
            currentPosition = lastPosition + ((currentPosition - lastPosition) / 2);
        } 
        else {
            float temp = currentPosition;
            currentPosition = currentPosition + ((currentPosition - lastPosition) / 2);
            lastPosition = temp;
        }
    }

    float reflectionVisibility = hitSecondPass ? 1 : 0;
    // TODO: avoid calculus if no visibility
    // attenuate if reflected facing camera
    // reflectionVisibility *= (1 - max(dot(viewDirection, reflectedDirection), 0));
    // attenuate if ???
    // reflectionVisibility *= (1 - clamp(depthDifference / SSR_THICKNESS, 0, 1));
    // attenuate as it is near of max distance
    // reflectionVisibility *= (1 - clamp(length()));
    // set visibility to 0 if outside of camera frustum
    reflectionVisibility *= (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x ? 0 : 1)
                          * (screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y ? 0 : 1);
    
    //reflectionVisibility = 1;

    if (reflectionVisibility == 0)
        return vec4(0);

    //vec3 reflectionColor = texture2D(colortex0, screenSpaceCurrentPosition.xy).rgb;
    return vec4(reflectionColor, reflectionVisibility);
}

// results
/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0;

void main() {

    /* opaque buffers values */
    // albedo
    vec4 albedoData_opaque = texture2D(colortex0, uv);
    vec3 albedo_opaque = pow(albedoData_opaque.rgb, vec3(2.2));
    float transparency_opaque = albedoData_opaque.a;
    // normal
    vec3 normal_opaque = texture2D(colortex1, uv).xyz *2 -1;
    // indirect sky & block light and type
    vec3 lightAndTypeData_opaque = texture2D(colortex2, uv).xyz;
    vec2 lightData_opaque = pow(lightAndTypeData_opaque.xy, vec2(2.2));
    float blockLightIntensity_opaque = lightData_opaque.x;
    float ambiantSkyLightIntensity_opaque = lightData_opaque.y;
    float type_opaque = lightAndTypeData_opaque.z;
    // material type
    vec4 typeData = texture2D(colortex6, uv);
    // depth
    float depth_opaque = texture2D(depthtex1, uv).x;
    float distanceFromCamera_opaque = linearizeDepth(depth_opaque);
    float linearDepth_opaque = distanceFromCamera_opaque / far;
    // view space position
    vec3 viewSpacePositionREALData = texture2D(colortex7, uv).xyz;
    vec3 viewSpacePositionREAL = vec3(viewSpacePositionREALData.xy, -viewSpacePositionREALData.z*100);

    /* transparent buffers values */
    // albedo
    vec4 albedoData_transparent = texture2D(colortex3, uv);
    vec3 albedo_transparent = pow(albedoData_transparent.rgb, vec3(2.2));
    float transparency_transparent = albedoData_transparent.a;
    // normal
    vec3 normal_transparent = texture2D(colortex4, uv).xyz *2 -1;
    // indirect sky & block light and type
    vec3 lightAndTypeData_transparent = texture2D(colortex5, uv).xyz;
    vec2 lightData_transparent = pow(lightAndTypeData_transparent.xy, vec2(2.2));
    float blockLightIntensity_transparent = lightData_transparent.x;
    float ambiantSkyLightIntensity_transparent = lightData_transparent.y;
    float type_transparent = lightAndTypeData_transparent.z;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;
    float distanceFromCamera_all = linearizeDepth(depth_all);
    float linearDepth_all = distanceFromCamera_all / far;


    // outColor0 = vec4(vec3(typeData.x), 1); return;

    // basic material
    // if (type_opaque == 0) {
    //     outColor0 = vec4(pow(albedo_opaque, vec3(1/2.2)), transparency_opaque); 
    //     return;
    // }


    // view space pos
    vec3 NDCPos = vec3(uv, depth_opaque) * 2.0 - 1.0;
    vec3 viewSpacePosition = projectAndDivide(gbufferProjectionInverse, NDCPos);
    viewSpacePosition = screenToView(uv, depth_opaque);

    // view space normal
    vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal_opaque);

    // view space tangent 
    vec3 t1 = cross(normal_opaque, vec3(0,0,1));
    vec3 t2 = cross(normal_opaque, vec3(0,1,0));
    vec3 tangent = length(t1)>length(t2) ? t1 : t2;
    tangent = normalize(tangent);
    vec3 viewSpaceTangent = mat3(gbufferModelView) * tangent;

    // view space bitangent
    vec3 viewSpaceBitangent = cross(viewSpaceTangent, viewSpaceNormal);
    viewSpaceBitangent = normalize(viewSpaceBitangent);

    // tbn
    mat3 TBN = mat3(viewSpaceTangent, viewSpaceBitangent, viewSpaceNormal);

    // -- Screen Space Ambiant Occlusion -- //
    float occlusion = SSAO(uv, depth_all, TBN);
    occlusion = map(occlusion, 0, 1, 0.2, 1);





    // -- Screen Space Reflection -- //
    // vec4 reflectionData = SSR_naze(viewSpacePosition, viewSpaceNormal);
    // vec3 reflectionColor = reflectionData.rgb;
    // float reflectionVisibility = reflectionData.a;
    // outColor0 = vec4(mix(albedo_opaque, reflectionColor, reflectionVisibility), 1); return;




    // -- Screen Space Reflection -- //
    vec4 reflectionData = SSR(viewSpacePosition, viewSpaceNormal);
    vec3 reflectionColor = reflectionData.rgb;
    float reflectionVisibility = reflectionData.a;
    outColor0 = vec4(mix(albedo_opaque, reflectionColor, reflectionVisibility), 1); return;


    

    /* early debug */
    // outColor0 = vec4(mix(albedo_opaque, reflectionColor, 0.5), visibility); return;
    // outColor0 = vec4(reflectionColor, visibility); return;

    // linearDepth_all = typeData.z;
    // linearDepth_opaque = typeData.z;



    /* uniform infos */
    // moon phase
    float moonPhaseBlend = moonPhase < 4 ? moonPhase*1./4. : (4.-(moonPhase*1.-4.))/4.; 
    moonPhaseBlend = cos(moonPhaseBlend * PI) / 2. + 0.5; // [0;1] new=0, full=1
    // day time
    vec3 upDirection = vec3(0,1,0);
    vec3 sunLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunDirectionDotUp = dot(sunLightDirectionWorldSpace, upDirection);
    vec3 shadowLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    /* light colors */
    // sun color
    float sunDawnColorTemperature = 2000.;
    float sunZenithColorTemperature = 6000.;
    float sunColorTemperature = clamp(cosThetaToSigmoid(sunDirectionDotUp, 0.1, 5.5) * (sunZenithColorTemperature-sunDawnColorTemperature) + sunDawnColorTemperature, 
                                        sunDawnColorTemperature, 
                                        sunZenithColorTemperature); // [2000;7000] depending at sun angle
    vec3 sunLightColor = kelvinToRGB(sunColorTemperature); 
    // moon color
    float moonDawnColorTemperature = 20000.;
    float moonFullMidnightColorTemperature = 7500.;
    float moonNewMidnightColorTemperature = 20000.;
    float moonMidnightColorTemperature = clamp(moonPhaseBlend * (moonFullMidnightColorTemperature-moonNewMidnightColorTemperature) + moonNewMidnightColorTemperature, 
                                        moonFullMidnightColorTemperature, 
                                        moonNewMidnightColorTemperature); // taking moon phase account
    float moonColorTemperature = clamp(cosThetaToSigmoid(abs(sunDirectionDotUp), 5., 5.5) * (moonMidnightColorTemperature-moonDawnColorTemperature) + moonDawnColorTemperature, 
                                        moonMidnightColorTemperature, 
                                        moonDawnColorTemperature);
    vec3 moonLightColor = 0.5 * kelvinToRGB(moonColorTemperature); 
    // sky color 
    vec3 rainySkyColor = 0.9 * kelvinToRGB(8000);
    float skyDayNightBlend = sigmoid(sunDirectionDotUp, 1., 50.);
    vec3 skyLightColor = mix(moonLightColor, sunLightColor, skyDayNightBlend);
    skyLightColor = mix(skyLightColor, rainySkyColor, rainStrength); // reduce contribution if it rain
    skyLightColor = pow(skyLightColor, vec3(2.2));
    // emissive block color 
    float blockColorTemperature = 5000.;
    vec3 blockLightColor = kelvinToRGB(blockColorTemperature);
    blockLightColor = pow(blockLightColor, vec3(2.2));

    // outColor0 = vec4(vec3(albedo_opaque), 1); return;

    // init albedo 
    vec3 outColor_opaque = vec3(0);
    vec3 outColor_transparent = vec3(0);

    // lit material
    if (type_opaque == 1) {
        // directions and angles
        float shadowDirectionDotNormal = dot(shadowLightDirectionWorldSpace, normal_opaque);

        /* shadow */
        vec3 shadow = getSoftShadow(uv, depth_opaque, gbufferProjectionInverse, gbufferModelViewInverse);
        // decrease shadow with distance
        float startShadowDecrease = 200;
        float endShadowDecrease = 250;
        float shadowBlend = clamp((distanceFromCamera_opaque - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
        shadow = mix(shadow, vec3(1), shadowBlend);

        /* lighting */
        // direct sky light
        float rainFactor = max(1-rainStrength, 0.05);
        vec3 skyDirectLight = shadow * max(shadowDirectionDotNormal, 0) * skyLightColor;
        skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
        // ambiant sky light
        float ambiantFactor = 0.2;
        vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity_opaque;
        // emissive block light
        vec3 blockLight = blockLightColor * blockLightIntensity_opaque;
        // perfect diffuse
        outColor_opaque = albedo_opaque * occlusion * (skyDirectLight + ambiantSkyLight + blockLight);
        outColor_opaque = pow(outColor_opaque, vec3(1/2.2));

        /* fog */
        // custom fog
        float density = mix(2.5, 1.5, rainFactor);
        float customFogBlend = clamp(1 - pow(2, -(linearDepth_opaque*density)*(linearDepth_opaque*density)*(linearDepth_opaque*density)), 0, 1); // exponential function
        outColor_opaque = mix(outColor_opaque, fogColor, customFogBlend);
        // vanilla fog
        float vanillaFogBlend = clamp((distanceFromCamera_opaque - fogStart) / (fogEnd - fogStart), 0, 1);
        outColor_opaque = mix(outColor_opaque, fogColor, vanillaFogBlend);
    }

    // transparent material (avoid invisible pixels)
    if (depth_all<depth_opaque && transparency_transparent>alphaTestRef) {
        // directions and angles
        float shadowDirectionDotNormal = dot(shadowLightDirectionWorldSpace, normal_transparent);

        /* shadow */
        vec3 shadow = getSoftShadow(uv, depth_all, gbufferProjectionInverse, gbufferModelViewInverse);
        // decrease shadow with distance
        float startShadowDecrease = 125;
        float endShadowDecrease = 150;
        float shadowBlend = clamp((distanceFromCamera_all - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
        shadow = mix(shadow, vec3(1), shadowBlend);

        /* lighting */
        // direct sky light
        float rainFactor = max(1-rainStrength, 0.05);
        vec3 skyDirectLight = shadow * max(shadowDirectionDotNormal, 0) * skyLightColor;
        skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
        // ambiant sky light
        float ambiantFactor = 1;
        vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity_transparent;
        // emissive block light
        vec3 blockLight = blockLightColor * blockLightIntensity_transparent;
        // perfect diffuse
        outColor_transparent = albedo_transparent * (skyDirectLight + ambiantSkyLight + blockLight);
        outColor_transparent = pow(outColor_transparent, vec3(1/2.2));

        /* fog */
        // custom fog
        float density = mix(2.5, 1.5, rainFactor);
        float customFogBlend = clamp(1 - pow(2, -(linearDepth_all*density)*(linearDepth_all*density)*(linearDepth_all*density)), 0, 1); // exponential function
        outColor_transparent = mix(outColor_transparent, fogColor, customFogBlend);
        // vanilla fog
        float vanillaFogBlend = clamp((distanceFromCamera_all - fogStart) / (fogEnd - fogStart), 0, 1);
        outColor_transparent = mix(outColor_transparent, fogColor, vanillaFogBlend);
    }

    /* result */
    // outColor0 = vec4(outColor_opaque, transparency_opaque);
    // outColor0 = vec4(outColor_transparent, transparency_transparent);

    /* debug */
    // outColor0 = vec4(vec3(outColor0), 1);
    // shadow map
    // outColor0 = vec4(texture2D(shadowtex0, gl_FragCoord.xy/vec2(viewWidth,viewHeight)).rgb, 1);

    /* /!\ IMPORTANT /!\ */
    // blend opaque & transparent together
    outColor0 = vec4(vec3(mix(outColor_opaque, outColor_transparent, albedoData_transparent.a)), 1); return;
}
