#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#if REFLECTION_TYPE > 0
    #include "/lib/BRDF.glsl"
    #include "/lib/reflection.glsl"
#endif

// textures
uniform sampler2D colortex0; // color
uniform sampler2D depthtex0; // all depth
#if REFLECTION_TYPE > 0
    uniform sampler2D colortex1; // normal
    uniform sampler2D colortex5; // light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
#endif
#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex0; // DH all depth
#endif

in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;
#if REFLECTION_TYPE > 0
    /* RENDERTARGETS: 0,4,5 */
    layout(location = 1) out vec4 colorDeferredData;
    layout(location = 2) out vec4 lightAndMaterialData;
#endif

/******************************************/
/******* opaque material reflection *******/
/******************************************/
void main() {

    // retrieve data
    vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);
    float depth = texture2D(depthtex0, uv).r;

    // color = linearToSRGB(color);
    // colorData = vec4(color, 1.0);
    // colorDeferredData = vec4(color, 0.0);
    // lightAndMaterialData = texture2D(colortex5, uv);
    // return;

    // -- reflection -- //
    #if REFLECTION_TYPE > 0
        // retrieve data used for reflection
        vec3 normal = decodeNormal(texture2D(colortex1, uv).xyz);
        vec4 lightAndMaterialDataInput = texture2D(colortex5, uv);
        float ambientSkyLightIntensity = lightAndMaterialDataInput.x;
        float emissivness = lightAndMaterialDataInput.y;
        float smoothness = lightAndMaterialDataInput.z;
        float reflectance = 1.0 - lightAndMaterialDataInput.w;
        vec3 worldSpacePosition = screenToWorld(uv, depth);

        // apply reflection
        vec4 reflection = doReflection(colortex0, colortex5, depthtex0, uv, depth, color, normal, ambientSkyLightIntensity, smoothness, reflectance, emissivness);
        // fog
        float fogFactor = getFogFactor(worldSpacePosition);
        reflection.a = mix(reflection.a, 0.0, fogFactor);
        // blindness
        float blindnessFogFactor = getBlindnessFactor(worldSpacePosition, blindnessRange);
        reflection.a = mix(reflection.a, 0.0, blindnessFogFactor * blindness);
        // darkness
        float darknessFogFactor = getBlindnessFactor(worldSpacePosition, darknessRange);
        reflection.a = mix(reflection.a, 0.0, darknessFogFactor * darknessFactor);

        // metallic material
        reflection.rgb *= color / max(color.r + 0.01, max(color.g, color.b));

        // apply fog on reflection visibility
        reflection.a = min(reflection.a, 1.0 - getFogFactor(worldSpacePosition));

        // apply reflection
        color = mix(color, reflection.rgb, reflection.a);
    #endif

    // add nether fog on background
    #ifdef NETHER
        #ifdef DISTANT_HORIZONS
            float DHdepth = texture2D(dhDepthTex0, uv).r;
            if (depth == 1.0 && DHdepth == 1.0)
        #else
            if (depth == 1.0)
        #endif
        {
            #if REFLECTION_TYPE == 0
                vec3 worldSpacePosition = screenToWorld(uv, depthAll);
            #endif
            float _;
            foggify(worldSpacePosition, color, _);
        }
    #endif

    // gamma correct
    color = linearToSRGB(color);

    // write buffer
    colorData = vec4(color, 1.0);
    #if REFLECTION_TYPE > 0
        colorDeferredData = vec4(color, 0.0);
        lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, 1.0 - reflectance);
    #endif
}
