#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex3; // opaque material (smoothness, reflectance, emissivness)
uniform sampler2D colortex4; // transparent color
uniform sampler2D colortex5; // transparent normal
uniform sampler2D colortex6; // transparent light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex7; // transparent material (smoothness, reflectance, emissivness)
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth
uniform sampler2D depthtex2; // only opaque depth and no hand

in vec3 planes_normal[6];
in vec3 planes_point[6];
in vec3 backgroundColor;

// attributes
in vec2 uv;

vec4 SSR_SecondPass(sampler2D colorTexture, sampler2D depthTexture, sampler2D lightTexture,
                    vec3 texelSpaceStartPosition, vec3 texelSpaceEndPosition, 
                    float startPositionDepth, float endPositionDepth,
                    float lastPosition, float currentPosition,
                    vec3 viewSpaceStartPosition, float reflectedDirectionDotZ) {
    
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

    // hit
    vec4 reflection = texture2D(colorTexture, screenSpaceCurrentPosition.xy);
    vec4 light = texture2D(lightTexture, screenSpaceCurrentPosition.xy);
    reflection.rgb = SRGBtoLinear(reflection.rgb) * (light.z+1);
    return reflection;
}

vec4 SSR(sampler2D colorTexture_opaque, sampler2D colorTexture_transparent, 
                 sampler2D depthTexture_opaque, sampler2D depthTexture_transparent, 
                 vec2 uv, float depth, vec3 normal, float smoothness, float reflectance) {
    
    // no reflections for perfectly rough surface
    if (smoothness <= 0.01) return vec4(0);

    // directions and angles in view space
    vec3 viewSpacePosition = screenToView(uv, depth);
    vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal);
    //vec3 viewSpaceNormal = normal;
    vec3 viewDirection = normalize(viewSpacePosition);
    vec3 reflectedDirection = normalize(reflect(viewDirection, viewSpaceNormal));
    float viewDirectionDotNormal = dot(-viewDirection, viewSpaceNormal);
    float reflectedDirectionDotZ = dot(reflectedDirection, vec3(0,0,-1));

    // fresnel index
    float reflectionVisibility = schlick(reflectance, viewDirectionDotNormal);
    if (reflectionVisibility <= 0.001)
        return vec4(0);
    
    // light version (only fresnel)
    vec4 reflection = vec4(backgroundColor, reflectionVisibility);
    if (SSR_ONLY_FRESNEL == 1) return reflection;

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

    // determine the step length
    float resolution = mix(0.01, SSR_RESOLUTION, smoothness);
    float isXtheLargestDimmension = abs(delta.x) > abs(delta.y) ? 1 : 0;
    float stepsNumber = max(abs(delta.x), abs(delta.y)) * clamp(resolution, 0, 1); // check which dimension has the longest to determine the number of steps
    vec2 stepLength = delta / stepsNumber;

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

    // 1st pass
    for (int i=0; i<int(stepsNumber); ++i) {
        texelSpaceCurrentPosition += vec3(stepLength, 1);
        screenSpaceCurrentPosition = texelToScreen(texelSpaceCurrentPosition);

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

    // set default reflection to end position value
    vec4 reflection_opaque = texture2D(colorTexture_opaque, screenSpaceEndPosition.xy);
    vec4 light = texture2D(colortex2, screenSpaceCurrentPosition.xy);
    reflection_opaque.rgb = SRGBtoLinear(reflection_opaque.rgb) * (1 + light.z*10);

    vec4 reflection_transparent = texture2D(colorTexture_transparent, screenSpaceEndPosition.xy);
    reflection_transparent.rgb = SRGBtoLinear(reflection_transparent.rgb);

    // blended with fresnel & avoid abrupt transition
    reflection = vec4(mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a), reflectionVisibility);
    float fadeFactor = pow(2*distanceInf(vec2(0.5), screenSpaceCurrentPosition.xy), 5);
    reflection.rgb = mix(reflection.rgb, backgroundColor, fadeFactor);

    // no hit
    if (!hitFirstPass_opaque && !hitFirstPass_transparent) {
        return reflection;
    }

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
            reflectedDirectionDotZ
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
            reflectedDirectionDotZ
        );

    // no second hit
    if (reflection_opaque.a <= alphaTestRef && reflection_transparent.a <= alphaTestRef)
        return reflection;
    
    // set reflection to hitted position
    reflection.rgb = mix(reflection_opaque.rgb, reflection_transparent.rgb, reflection_transparent.a);
    reflection.rgb = mix(reflection.rgb, backgroundColor, fadeFactor);
    return reflection;
}

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {

    ////// facto la lecture des buffers

    /* opaque buffers values */
    // albedo
    vec4 colorData_opaque = texture2D(colortex0, uv);
    colorData_opaque = SRGBtoLinear(colorData_opaque);
    vec3 color_opaque = colorData_opaque.rgb;
    float transparency_opaque = colorData_opaque.a;
    // normal
    vec4 normalData_opaque = texture2D(colortex1, uv);
    vec3 normal_opaque = decodeNormal(normalData_opaque.xyz);
    // light
    vec4 lightData_opaque = texture2D(colortex2, uv);
    vec2 receivedLight_opaque = lightData_opaque.xy;
    receivedLight_opaque = SRGBtoLinear(receivedLight_opaque);
    float blockLightIntensity_opaque = receivedLight_opaque.x;
    float ambiantSkyLightIntensity_opaque = receivedLight_opaque.y;
    float emissivness_opaque = lightData_opaque.z;
    // material
    vec4 materialData_opaque = texture2D(colortex3, uv);
    float type_opaque = materialData_opaque.x;
    float smoothness_opaque = materialData_opaque.y;
    float reflectance_opaque = materialData_opaque.z;
    // depth
    float depth_opaque = texture2D(depthtex1, uv).x;

    /* transparent buffers values */
    // albedo
    vec4 colorData_transparent = texture2D(colortex4, uv);
    colorData_transparent = SRGBtoLinear(colorData_transparent);
    vec3 color_transparent = colorData_transparent.rgb;
    float transparency_transparent = colorData_transparent.a;
    // normal
    vec4 normalData_transparent = texture2D(colortex5, uv);
    vec3 normal_transparent = normalData_transparent.xyz *2 -1;
    // light
    vec4 lightData_transparent = texture2D(colortex6, uv);
    vec2 receivedLight_transparent = lightData_transparent.xy;
    receivedLight_transparent = SRGBtoLinear(receivedLight_transparent);
    float blockLightIntensity_transparent = receivedLight_transparent.x;
    float ambiantSkyLightIntensity_transparent = receivedLight_transparent.y;
    float emissivness_transparent = lightData_transparent.z;
    // material
    vec4 materialData_transparent = texture2D(colortex7, uv);
    float type_transparent = materialData_transparent.x;
    float smoothness_transparent = materialData_transparent.y;
    float reflectance_transparent = materialData_transparent.z;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;

    // outColor = colorData_opaque;
    // return;

    // outColor = colorData_transparent;
    // return;

    // outColor = vec4(vec3(mix(color_opaque, color_transparent, transparency_transparent)), transparency_opaque);
    // return;



    // view space pos
    vec3 viewSpacePosition = screenToView(uv, depth_opaque);
    vec3 worldSpacePosition = viewToWorld(viewSpacePosition);
    // view space normal
    vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal_opaque);
    // view space tangent 
    vec3 t1 = cross(normal_opaque, vec3(0,0,1));
    vec3 t2 = cross(normal_opaque, vec3(0,1,0));
    vec3 tangent = length(t1)>length(t2) ? t1 : t2;
    tangent = normalize(tangent);
    vec3 viewSpaceTangent = normalize(mat3(gbufferModelView) * tangent);
    // view space bitangent
    vec3 viewSpaceBitangent = cross(viewSpaceTangent, viewSpaceNormal);
    viewSpaceBitangent = normalize(viewSpaceBitangent);
    // tbn - tangent to view 
    mat3 TBN = mat3(viewSpaceTangent, viewSpaceBitangent, viewSpaceNormal); 

    vec3 bitangent = cross(tangent, normal_opaque);
    bitangent = normalize(bitangent);
    mat3 TBNworld = mat3(tangent, bitangent, normal_opaque); 

    vec3 viewDirection = - normalize(viewSpacePosition);
    float roughness = pow(1.0 - smoothness_opaque, 2.0);
    roughness *= roughness;
    roughness = roughness;

    vec3 cul = mod(abs(worldSpacePosition), vec3(1));
    //cul = abs(cul*2 - 1);
    cul = transpose(TBNworld) * cul;
    cul = abs(cul);

    vec3 noise = getNoise1(cul.xy);
    noise = getNoise(uv);
    float zeta1 = noise.x, zeta2 = noise.y;

    viewDirection = transpose(TBN) * viewDirection;

    vec3 sampledNormal = sampleGGXVNDF(viewDirection, roughness, roughness, zeta1, zeta2);
    // sampledNormal = normalize(sampledNormal);

    // sampledNormal = sampleGGXNormal(uv, roughness);

    sampledNormal = TBN * sampledNormal;
    sampledNormal = viewToEye(sampledNormal);

    // outColor = vec4(noise, 1);
    // return;

    // -- LIT OPAQUE -- //
    if (type_opaque == 1) {
        vec4 reflectionData = SSR(
            colortex0, 
            colortex4, 
            depthtex2, 
            depthtex0, 
            uv, 
            depth_opaque, 
            sampledNormal,
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
            colortex4,
            depthtex2,
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
    outColor.rgb = linearToSRGB(outColor.rgb);
}
