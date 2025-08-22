#extension GL_ARB_explicit_attrib_location : enable

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex5; // light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

in vec2 uv;

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#include "/lib/shadow.glsl"
#include "/lib/animation.glsl"
#include "/lib/volumetric_light.glsl"

// results
/* RENDERTARGETS: 0,4,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec4 bloomData;
layout(location = 2) out vec4 depthOfFieldData;

/******************************************/
/************ volumetric light ************/
/******************************************/
void main() {
    // retrieve data
    vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);
    vec4 lightAndMaterialData = texture2D(colortex5, uv);

    // depth
    float depthAll = texture2D(depthtex0, uv).r;
    float depthOpaque = texture2D(depthtex1, uv).r;
    vec3 viewSpacePosition = screenToView(uv, depthOpaque);

    #if BLOOM_TYPE > 0 || DOF_TYPE > 0
        float emissivness = lightAndMaterialData.g;
    #else
        float emissivness = 0.0;
    #endif

    // apply underwater fog on sky box after water rendering
    if (isEyeInWater == 1 && depthAll == 1.0) {
        vec3 worldSpacePosition = screenToWorld(uv, depthAll);
        foggify(worldSpacePosition, color, emissivness);
    }

    // -- volumetric light -- //
    #if SHADOW_TYPE > 0 && VOLUMETRIC_LIGHT_TYPE > 0
        float ambientSkyLightIntensity = depthOpaque == 1.0 ? 1.0 : lightAndMaterialData.r;
        volumetricLighting(uv, depthOpaque, ambientSkyLightIntensity, color);
    #endif

    // gamma correct & write
    colorData = vec4(linearToSRGB(color), 1.0);

    // -- prepare new buffers -- //

    // -- bloom buffer -- //
    #if BLOOM_TYPE > 0

        // extract bloom from color
        vec3 bloom = color;
        float lightness = getLightness(bloom);
        bloom = bloom * max(pow(lightness, 10.0) * 0.125, map(emissivness, 0.0, 0.9, 0.0, 1.0));

        // apply darkness
        bloom = mix(bloom, 0.0 * bloom, clamp(2.0 * darknessLightFactor, 0.0, 1.0));

        // sun & moon special bloom
        float sunMask = map(emissivness, 0.9, 1.0, 0.0, 1.0);
        #if defined OVERWORLD && BLOOM_TYPE > 1
            bloom *= 1.0 - sunMask;
        #endif

        bloomData = vec4(linearToSRGB(bloom), sunMask);
    #else
        bloomData = vec4(0.0);
    #endif

    // -- depth of field buffer -- //
    depthOfFieldData = vec4(0.0, 0.0, map(emissivness, 0.0, 0.9, 0.0, 1.0), 1.0);
    #if DOF_TYPE > 0
        // actual distance
        float linearDepth = - viewSpacePosition.z;

        // blur amount
        #if DOF_TYPE == 1
            // focal plane distance
            float focusDepth = centerDepthSmooth > 0.99999 ? 1.0 : centerDepthSmooth;
            vec3 viewSpaceFocusPosition = screenToView(vec2(0.5), focusDepth);
            float focusDistance = - viewSpaceFocusPosition.z;
            focusDistance = min(focusDistance, far);

            float blurFactor = 0.0;
            if (focusDepth == 1.0) {
                blurFactor = depthOpaque < 1.0 ? 1.0 : 0.0;
            }
            else if (depthOpaque == 1.0) {
                blurFactor = 1.0;
            }
            else {
                float diff = abs(linearDepth - focusDistance);
                blurFactor = diff < DOF_FOCAL_PLANE_LENGTH ? 0.0 : 1.0;
                blurFactor *= map(diff, DOF_FOCAL_PLANE_LENGTH, 2.0 * DOF_FOCAL_PLANE_LENGTH, 0.0, 1.0);
            }
        #else
            float focusDistance = 0.0;
            float blurFactor = pow(linearDepth / far, 0.26);
        #endif

        // write buffer
        if (blurFactor > 0.0) {
            // near plane
            if (linearDepth < focusDistance) {
                depthOfFieldData.r = blurFactor;
            }
            // far plane
            else if (linearDepth > focusDistance) {
                depthOfFieldData.g = blurFactor;
            }
        }
    #endif
}
