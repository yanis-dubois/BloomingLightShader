#extension GL_ARB_explicit_attrib_location : enable

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex1; // normal
uniform sampler2D colortex2; // light & material (sky_ambiant_light, emmissivness, smoothness, reflectance)
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

in vec2 uv;

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/lightColor.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#include "/lib/shadow.glsl"
#include "/lib/volumetric_light.glsl"

// results
/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec3 bloomData;
layout(location = 2) out vec4 depthOfFieldData;

/******************************************/
/************ volumetric light ************/
/******************************************/
void main() {
    // retrieve data
    vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);

    // depth
    float depthAll = texture2D(depthtex0, uv).r;
    float depthOpaque = texture2D(depthtex1, uv).r;

    // apply underwater fog on sky box after water rendering
    if (isEyeInWater == 1 && depthAll == 1.0) {
        vec3 worldSpacePosition = screenToWorld(uv, depthAll);
        color = foggify(color, worldSpacePosition);
    }

    // -- volumetric light -- //
    #if VOLUMETRIC_LIGHT_TYPE > 0
        volumetricLighting(uv, depthAll, depthOpaque, true, color);
    #endif

    // gamma correct & write
    colorData = vec4(linearToSRGB(color), 1.0);

    // -- prepare new buffers -- //

    // -- bloom buffer -- //
    #if BLOOM_TYPE > 0
        float emissivness = texture2D(colortex2, uv).g;
        float lightness = getLightness(color);

        vec3 bloom = color * max(pow(lightness, 5) * 0.5, 2.0 * emissivness);
        bloomData = linearToSRGB(bloom);
    #else
        bloomData = vec3(0.0);
    #endif

    // -- depth of field buffer -- //
    depthOfFieldData = vec4(vec3(0.0), 1.0);
    #if DOF_TYPE > 0
        // actual distance
        vec3 viewSpacePosition = screenToView(uv, depthOpaque);
        float linearDepth = - viewSpacePosition.z;

        // blur amount
        #if DOF_TYPE == 1
            // focal plane distance
            float focusDepth = texture2D(depthtex1, vec2(0.5)).r;
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
            float blurFactor = pow(linearDepth / far, 1.8);
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
