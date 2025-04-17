#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"

#if REFLECTION_TYPE == 0
    void main() {}

#else
    #include "/lib/utils.glsl"
    #include "/lib/space_conversion.glsl"
    #include "/lib/light_color.glsl"
    #include "/lib/sky.glsl"
    #include "/lib/fog.glsl"
    #include "/lib/BRDF.glsl"
    #include "/lib/reflection.glsl"

    // textures
    uniform sampler2D colortex0; // color
    uniform sampler2D colortex1; // normal
    uniform sampler2D colortex5; // light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
    uniform sampler2D depthtex0; // all depth

    in vec2 uv;

    // results
    /* RENDERTARGETS: 4 */
    layout(location = 0) out vec4 reflectionData;

    /******************************************/
    /******* opaque material reflection *******/
    /******************************************/
    void main() {

        // retrieve data
        vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);
        vec3 normal = decodeNormal(texture2D(colortex1, uv).xyz);
        vec4 lightAndMaterialData = texture2D(colortex5, uv);
        float ambientSkyLightIntensity = lightAndMaterialData.x;
        float smoothness = lightAndMaterialData.z;
        float reflectance = lightAndMaterialData.w;
        float depth = texture2D(depthtex0, uv).r;

        // apply reflection
        vec4 reflection = doReflection(colortex0, colortex5, depthtex0, uv, depth, color, normal, ambientSkyLightIntensity, smoothness, reflectance);
        // fog
        vec3 worldSpacePosition = screenToWorld(uv, depth);
        float fogFactor = getFogFactor(worldSpacePosition, isEyeInWater==1);
        reflection.a = mix(reflection.a, 0.0, fogFactor);
        // blindness
        float blindnessFogFactor = getBlindnessFactor(worldSpacePosition, blindnessRange);
        reflection.a = mix(reflection.a, 0.0, blindnessFogFactor * blindness);
        // darkness
        float darknessFogFactor = getBlindnessFactor(worldSpacePosition, darknessRange);
        reflection.a = mix(reflection.a, 0.0, darknessFogFactor * darknessFactor);

        // metallic material
        reflection.rgb *= color / max(color.r + 0.01, max(color.g, color.b));    

        // gamma correct
        reflection.rgb = linearToSRGB(reflection.rgb);

        // write buffer
        reflectionData = vec4(reflection);
    }
#endif
