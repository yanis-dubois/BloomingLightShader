#extension GL_ARB_explicit_attrib_location : enable

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex1; // normal
uniform sampler2D colortex5; // light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
uniform sampler2D depthtex0; // all depth

in vec2 uv;

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/BRDF.glsl"
#include "/lib/reflection.glsl"

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;

#if SSR_TYPE > 0
    /* RENDERTARGETS: 0,4,5 */
    layout(location = 1) out vec4 reflectionColorData;
    layout(location = 2) out vec4 reflectionLightAndMaterialData;
#endif

/******************************************/
/******* opaque material reflection *******/
/******************************************/
void main() {

    // -- reflection -- //
    #if SSR_TYPE > 0
        // retrieve data
        vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);
        vec3 normal = decodeNormal(texture2D(colortex1, uv).xyz);
        vec4 lightAndMaterialData = texture2D(colortex5, uv);
        float ambientSkyLightIntensity = lightAndMaterialData.x;
        float emissivness = lightAndMaterialData.y;
        float smoothness = lightAndMaterialData.z;
        float reflectance = lightAndMaterialData.w;
        float depth = texture2D(depthtex0, uv).r;

        // apply reflection
        vec4 reflection = doReflection(colortex0, colortex5, depthtex0, uv, depth, color, normal, ambientSkyLightIntensity, smoothness, reflectance);
        color = mix(color, reflection.rgb, reflection.a);

        // gamma correct
        color = linearToSRGB(color);

        // write buffers
        colorData = vec4(color, 1.0);
        // custom texture for reflection on transparent material (color, emissivness)
        reflectionColorData = vec4(color, 1.0);
        reflectionLightAndMaterialData = vec4(0.0, emissivness, 0.0, 0.0);
    #else
        colorData = texture2D(colortex0, uv);
    #endif

}
