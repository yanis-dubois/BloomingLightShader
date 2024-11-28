#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/sample.glsl"

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

vec4 SSR(vec3 viewSpacePosition, vec3 viewSpaceNormal) {
    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));
    float maxDistance = clamp(SSR_MAX_DISTANCE, 0, 1) * far;

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

    float reflectionVisibility = hitSecondPass ? 1 : 0;
    // TODO: avoid calculus if no visibility
    reflectionVisibility *= schlick(1.33, dot(-viewDirection, viewSpaceNormal));
    reflectionVisibility *= (screenSpaceCurrentPosition.x<0 || 1<screenSpaceCurrentPosition.x ? 0 : 1)
                          * (screenSpaceCurrentPosition.y<0 || 1<screenSpaceCurrentPosition.y ? 0 : 1);
    
    if (reflectionVisibility == 0)
        return vec4(0);

    vec3 reflectionColor = texture2D(colortex0, screenSpaceCurrentPosition.xy).rgb;
    return vec4(reflectionColor, reflectionVisibility);
}

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

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

    outColor0 = vec4(vec3(mix(color_opaque, color_transparent, transparency_transparent)), 1); 
    // return;


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


    // -- Screen Space Reflection -- //
    vec4 reflectionData = SSR(viewSpacePosition, viewSpaceNormal);
    vec3 reflectionColor = reflectionData.rgb;
    float reflectionVisibility = reflectionData.a;
    outColor0 = vec4(mix(color_opaque, reflectionColor, reflectionVisibility), 1); 
    return;
}
