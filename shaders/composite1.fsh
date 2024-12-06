#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque type : x=material_type[0:basic,0.5:transparent,1:lit]
uniform sampler2D colortex3; // transparent color
uniform sampler2D colortex4; // transparent normal
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

// attributes
in vec2 uv;

vec4 SSR_SecondPass(sampler2D colorTexture, sampler2D depthTexture,
                    vec3 texelSpaceStartPosition, vec3 texelSpaceEndPosition, 
                    float startPositionDepth, float endPositionDepth,
                    float lastPosition, float currentPosition) {
    
    // init
    vec3 texelSpaceCurrentPosition = vec3(0);
    vec3 screenSpaceCurrentPosition = vec3(0);
    float lastTopPosition = lastPosition, lastUnderPosition = currentPosition;
    float currentPositionDepth = 0;
    float actualPositionDepth = 0;
    float depthDifference = SSR_THICKNESS;
    bool hitSecondPass = false;

    // 2nd pass
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
            break;
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
    reflectionVisibility *= (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x ? 0 : 1)
                          * (screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y ? 0 : 1);
    
    if (reflectionVisibility == 0)
        return vec4(0);

    return texture2D(colorTexture, screenSpaceCurrentPosition.xy);
}

vec4 SSR(sampler2D colorTexture_opaque, sampler2D colorTexture_transparent, 
                 sampler2D depthTexture_opaque, sampler2D depthTexture_transparent, 
                 vec2 uv, float depth, vec3 normal) {
    
    // TODO: gérer le ciel
    
    // convert to view space
    vec3 viewSpacePosition = screenToView(uv, depth);
    vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal);

    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));
    float maxDistance = clamp(SSR_MAX_DISTANCE, 0, 1) * far;
    float cosTheta = dot(-viewDirection, viewSpaceNormal);

    // early reject
    float reflectionVisibility = schlick(1.33, cosTheta);
    if (reflectionVisibility < 0.025)
        return vec4(0);

    vec3 viewSpaceStartPosition = viewSpacePosition;
    vec3 viewSpaceEndPosition = rayFrustumIntersection(viewSpaceStartPosition, reflectedDirection);

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
    float lastPosition_transparent = 0, currentPosition_transparent = 0;

    // initialize some variable
    vec3 texelSpaceCurrentPosition = texelSpaceStartPosition;
    vec3 screenSpaceCurrentPosition = screenSpaceStartPosition;
    float currentPositionDepth = 0;
    float actualPositionDepth_opaque = startPositionDepth;
    float actualPositionDepth_transparent = startPositionDepth;
    float depthDifference = SSR_THICKNESS;
    bool hitFirstPass_opaque = false, hitFirstPass_transparent = false, hitSecondPass = false;

    float debug=0, debug2=0, debug3=0;

    // 1st pass
    for (int i=0; i<int(stepsNumber); ++i) {
        texelSpaceCurrentPosition += vec3(stepLength, 1);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // stop if outside frustum
        if (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x 
        || screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y) {
            debug2 = 1;
            break;
        }

        // depth at this uv coordinate
        actualPositionDepth_opaque = - screenToView(
            screenSpaceCurrentPosition.xy, 
            texture2D(depthTexture_opaque, screenSpaceCurrentPosition.xy).r
        ).z;
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
        currentPositionDepth = - perspectiveMix(startPositionDepth, endPositionDepth, currentPosition);
        if (currentPositionDepth < 0) {
            debug3 = 1;
            break;
        }

        // hit opaque surface
        if (currentPositionDepth > actualPositionDepth_opaque) {
            hitFirstPass_opaque = true;
            debug = 1;
            break;
        } 
        // hit transparent surface
        else if (!hitFirstPass_transparent && currentPositionDepth > actualPositionDepth_transparent) {
            hitFirstPass_transparent = true;
            lastPosition_transparent = lastPosition;
            currentPosition_transparent = currentPosition;
        }
        
        lastPosition = currentPosition;
    }

    // return vec4(debug, debug2, debug3, 1);

    if (!hitFirstPass_opaque && !hitFirstPass_transparent)
        return vec4(0);

    vec4 reflection_opaque = vec4(0), reflection_transparent = vec4(0);
    if (hitFirstPass_opaque)
        reflection_opaque = SSR_SecondPass(
            colorTexture_opaque, 
            depthTexture_opaque,
            texelSpaceStartPosition, 
            texelSpaceEndPosition, 
            startPositionDepth,
            endPositionDepth,
            lastPosition, 
            currentPosition
        );
    
    if (hitFirstPass_transparent)
        reflection_transparent = SSR_SecondPass(
            colorTexture_transparent, 
            depthTexture_transparent,
            texelSpaceStartPosition, 
            texelSpaceEndPosition, 
            startPositionDepth,
            endPositionDepth,
            lastPosition_transparent, 
            currentPosition_transparent
        );
    
    vec3 reflectionColor = mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a);
    
    return vec4(reflectionColor, reflectionVisibility);
}

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {

    /* opaque buffers values */
    // color
    vec4 colorData_opaque = texture2D(colortex0, uv);
    vec3 color_opaque = colorData_opaque.rgb;
    float transparency_opaque = colorData_opaque.a;
    // normal
    vec4 normalData_opaque = texture2D(colortex1, uv);
    vec3 normal_opaque = normalData_opaque.xyz *2 -1;
    // type
    vec4 typeData_opaque = texture2D(colortex2, uv);
    float type_opaque = typeData_opaque.x;
    // depth
    float depth_opaque = texture2D(depthtex1, uv).x;

    /* transparent buffers values */
    // color
    vec4 colorData_transparent = texture2D(colortex3, uv);
    vec3 color_transparent = colorData_transparent.rgb;
    float transparency_transparent = colorData_transparent.a;
    // normal
    vec4 normalData_transparent = texture2D(colortex4, uv);
    vec3 normal_transparent = normalData_transparent.xyz *2 -1;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;

    // outColor = colorData_opaque;
    // return;

    // outColor = colorData_transparent;
    // return;

    // outColor = vec4(vec3(colorData_transparent.a), 1);
    // return;

    outColor = vec4(vec3(mix(color_opaque, color_transparent, transparency_transparent)), transparency_opaque);
    return;

    // -- LIT MATERIAL -- //
    if (type_opaque == 1) {
        vec4 reflectionData = SSR(colortex0, colortex3, depthtex1, depthtex0, uv, depth_opaque, normal_opaque);
        vec3 reflectionColor = reflectionData.rgb;
        float reflectionVisibility = reflectionData.a;
        color_opaque = mix(color_opaque, reflectionColor, reflectionVisibility);
    }
    
    // -- TRANSPARENT MATERIAL -- //
    if (depth_all<depth_opaque && transparency_transparent>alphaTestRef) {
        vec4 reflectionData = SSR(colortex0, colortex3, depthtex1, depthtex0, uv, depth_all, normal_transparent);
        vec3 reflectionColor = reflectionData.rgb;
        float reflectionVisibility = reflectionData.a;
        color_transparent = mix(color_transparent, reflectionColor, reflectionVisibility); 
    }

    /* mix opaque & transparent */
    outColor = vec4(vec3(mix(color_opaque, color_transparent, transparency_transparent)), 1);
}
