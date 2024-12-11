#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque material : x=material_type, y=smoothness, z=reflectance
uniform sampler2D colortex3; // transparent color
uniform sampler2D colortex4; // transparent normal
uniform sampler2D colortex5; // transparent material : x=material_type, y=smoothness, z=reflectance
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

in vec3 planes_normal[6];
in vec3 planes_point[6];
in vec3 backgroundColor;

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
    
    if (reflectionVisibility <= alphaTestRef)
        return vec4(0);

    vec4 reflection = texture2D(colorTexture, screenSpaceCurrentPosition.xy);

    return reflection;
}

vec4 SSR(sampler2D colorTexture_opaque, sampler2D colorTexture_transparent, 
                 sampler2D depthTexture_opaque, sampler2D depthTexture_transparent, 
                 vec2 uv, float depth, vec3 normal, float smoothness, float reflectance) {
    
    if (smoothness <= 0.01) return vec4(0);

    // directions and angles in view space
    vec3 viewSpacePosition = screenToView(uv, depth);
    vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal);
    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));
    float maxDistance = clamp(SSR_MAX_DISTANCE, 0, 1) * far;
    float cosTheta = dot(-viewDirection, viewSpaceNormal);

    // fresnel
    float reflectionVisibility = schlick(reflectance, cosTheta);
    if (reflectionVisibility <= 0.001)
        return vec4(0);

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
        return vec4(0);
    }

    // default value is end point
    vec4 reflection_opaque = texture2D(colorTexture_opaque, screenSpaceEndPosition.xy);
    vec4 reflection_transparent = texture2D(colorTexture_transparent, screenSpaceEndPosition.xy);
    vec4 reflection = vec4(mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a), reflectionVisibility);

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

    // 1st pass
    for (int i=0; i<int(stepsNumber); ++i) {
        texelSpaceCurrentPosition += vec3(stepLength, 1);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

        // stop if outside frustum [TODO: fade]
        if (!isInRange(screenSpaceCurrentPosition.xy, 0.005, 0.995)) {
            return vec4(backgroundColor, reflectionVisibility);
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
            break;
        }

        // hit opaque surface
        if (currentPositionDepth > actualPositionDepth_opaque) {
            hitFirstPass_opaque = true;
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

    float fadeFactor = pow(2*distanceInf(vec2(0.5), screenSpaceCurrentPosition.xy), 5);
    reflection.rgb = mix(reflection.rgb, backgroundColor, fadeFactor);

    if (!hitFirstPass_opaque && !hitFirstPass_transparent)
        return reflection;

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
    
    if (reflection_opaque.a <= alphaTestRef && reflection_transparent.a <= alphaTestRef)
        return reflection;
    
    reflection.rgb = mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a);
    reflection.rgb = mix(reflection.rgb, backgroundColor, fadeFactor);
    
    return reflection;
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
    // material
    vec4 typeData_opaque = texture2D(colortex2, uv);
    float type_opaque = typeData_opaque.x;
    float smoothness_opaque = typeData_opaque.y;
    float reflectance_opaque = typeData_opaque.z;
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
    // material
    vec4 typeData_transparent = texture2D(colortex5, uv);
    float type_transparent = typeData_transparent.x;
    float smoothness_transparent = typeData_transparent.y;
    float reflectance_transparent = typeData_transparent.z;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;

    // outColor = colorData_opaque;
    // return;

    // outColor = colorData_transparent;
    // return;

    // outColor = vec4(vec3(mix(color_opaque, color_transparent, transparency_transparent)), transparency_opaque);
    // return;

    // -- LIT OPAQUE -- //
    if (type_opaque == 1) {
        vec4 reflectionData = SSR(
            colortex0, 
            colortex3, 
            depthtex1, 
            depthtex0, 
            uv, 
            depth_opaque, 
            normal_opaque,
            smoothness_opaque, 
            reflectance_opaque
        );

        vec3 reflectionColor = reflectionData.rgb;
        float reflectionVisibility = reflectionData.a;
        color_opaque = mix(color_opaque, reflectionColor, reflectionVisibility);
    }
    
    // -- LIT TRANSPARENT -- //
    if (type_transparent == 1 && depth_all<depth_opaque && transparency_transparent>alphaTestRef) {
        vec4 reflectionData = SSR(
            colortex0,
            colortex3,
            depthtex1,
            depthtex0,
            uv,
            depth_all,
            normal_transparent,
            smoothness_transparent,
            reflectance_transparent
        );

        vec3 reflectionColor = reflectionData.rgb;
        float reflectionVisibility = reflectionData.a;
        color_transparent = mix(color_transparent, reflectionColor, reflectionVisibility); 
    }

    /* mix opaque & transparent */
    outColor = vec4(vec3(mix(color_opaque, color_transparent, transparency_transparent)), transparency_opaque);
    // outColor = mix(outColor, vec4(0), 2*(distanceInf(vec2(0.5), uv)));
}
