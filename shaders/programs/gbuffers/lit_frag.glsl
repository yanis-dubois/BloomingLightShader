#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#include "/lib/animation.glsl"
#include "/lib/shadow.glsl"
#include "/lib/BRDF.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting.glsl"
#if REFLECTION_TYPE > 0 && defined TRANSPARENT
    #include "/lib/reflection.glsl"
#endif

// uniforms
uniform sampler2D gtexture;

#if REFLECTION_TYPE > 0 && defined TRANSPARENT
    uniform sampler2D colortex4; // opaque color
    uniform sampler2D colortex5; // opaque light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
    uniform sampler2D depthtex1; // opaque depth
#endif

// attributes
in mat3 TBN;
in vec4 additionalColor; // albedo of : foliage, water, particules
in vec3 unanimatedWorldPosition;
in vec3 midBlock;
in vec3 worldSpacePosition;
in vec2 textureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
flat in int id;

// results
/* RENDERTARGETS: 0,1,4,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec3 normalData;
layout(location = 2) out vec4 reflectionData;
layout(location = 3) out vec4 lightAndMaterialData;

void main() {
    // retrieve data
    vec2 uv = texelToScreen(gl_FragCoord.xy);
    float depth = gl_FragCoord.z;
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 tint = additionalColor.rgb;
    vec3 albedo = textureColor.rgb * tint;
    float transparency = textureColor.a;

    vec3 tangent = TBN[0];
    vec3 bitangent = TBN[1];
    vec3 normal = TBN[2];

    // tweak transparency
    if (id == 20010) transparency = clamp(transparency, 0.2, 0.75); // uncolored glass
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;

    // avoid seeing water top surface when underwater
    if (isEyeInWater == 1 && id == 20000 && normal.y > 0.1) {
        discard;
    }

    // apply red flash when mob are hitted
    albedo = mix(albedo, entityColor.rgb, entityColor.a);

    // weather smooth transition
    #ifdef WEATHER
        transparency *= rainStrength;
        transparency = min(transparency, 0.2);
    #endif

    // light data
    float distanceFromEye = distance(eyePosition, worldSpacePosition);
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2);
    float heldBlockLight = heldLightValue >= 1.0 ? max(1.0 - (distanceFromEye / max(heldLightValue, 1.0)), 0.0) : 0.0;
    float blockLightIntensity = max(lightMapCoordinate.x, heldBlockLight);
    float ambientSkyLightIntensity = lightMapCoordinate.y;
    // gamma correct light
    blockLightIntensity = SRGBtoLinear(blockLightIntensity);
    ambientSkyLightIntensity = SRGBtoLinear(ambientSkyLightIntensity);

    // material data
    float smoothness = 0.0, reflectance = 0.0, emissivness = 0.0, ambient_occlusion = 0.0;
    getMaterialData(gtexture, id, normal, midBlock, textureColor.rgb, tint, albedo, smoothness, reflectance, emissivness, ambient_occlusion);  

    // particle normal tweak (every particles as subsurface)
    #ifdef PARTICLE
        normal = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        tangent = vec3(0.0, 0.0, 1.0);
        bitangent = cross(tangent, normal);
    #endif

    // animated normal
    #if ANIMATED_POSITION == 2 && defined REFLECTIVE
        if (isAnimated(id) && smoothness > 0.5) {
            vec3 actualPosition = doAnimation(id, frameTimeCounter, unanimatedWorldPosition, midBlock, ambientSkyLightIntensity);
            vec3 tangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + tangent / 16.0, midBlock, ambientSkyLightIntensity);
            vec3 bitangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + bitangent / 16.0, midBlock, ambientSkyLightIntensity);

            vec3 newTangent = normalize(tangentDerivative - actualPosition);
            vec3 newBitangent = normalize(bitangentDerivative - actualPosition);

            vec3 newNormal = - normalize(cross(newTangent, newBitangent));
            if (dot(newNormal, normal) < 0.0) newNormal *= -1.0;

            vec3 viewDirection = normalize(cameraPosition - actualPosition);
            if (dot(viewDirection, newNormal) > 0.1) {
                normal = newNormal;
            }
        }
    #endif

    // jittering normal for specular & reflective materials
    #if defined TERRAIN && PIXELATED_REFLECTION == 2
        if (smoothness > 0.1 && hasNormalJittering(id)) {
            vec4 seed = texture2DLod(gtexture, textureCoordinate, 0).rgba;
            float zeta1 = pseudoRandom(seed), zeta2 = pseudoRandom(seed + 41.43291);
            mat3 animatedTBN = generateTBN(normal);

            // sampling data
            float roughness = clamp(pow(1.0 - smoothness, 2.0), 0.1, 0.4);
            roughness *= roughness;

            // view direction from view to tangent space
            vec3 viewDirection = normalize(cameraPosition - voxelize(unanimatedWorldPosition));
            vec3 tangentSpaceViewDirection = transpose(animatedTBN) * viewDirection;
            // sample normal & convert to view
            vec3 sampledNormal = sampleGGXVNDF(tangentSpaceViewDirection, roughness, roughness, zeta1, zeta2);

            normal = animatedTBN * sampledNormal;
        }
    #endif

    // light animation
    #if ANIMATED_EMISSION > 0
        if (isAnimatedLight(id)) {
            float noise = doLightAnimation(id, frameTimeCounter, unanimatedWorldPosition);
            emissivness -= noise;
        }
    #endif

    // -- apply lighting -- //
    albedo = SRGBtoLinear(albedo);
    vec4 color = doLighting(gl_FragCoord.xy, albedo, transparency, normal, tangent, bitangent, worldSpacePosition, unanimatedWorldPosition, smoothness, reflectance, 1.0, ambientSkyLightIntensity, blockLightIntensity, emissivness, ambient_occlusion);

    // -- reflection on transparent material -- //
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        #if PIXELATED_REFLECTION > 0
            vec3 screenSpacePosition = worldToScreen((unanimatedWorldPosition));
        #else
            vec3 screenSpacePosition = vec3(uv, depth);
        #endif
        vec4 reflection = doReflection(colortex4, colortex5, depthtex1, screenSpacePosition.xy, screenSpacePosition.z, color.rgb, normal, ambientSkyLightIntensity, smoothness, reflectance);

        // tweak reflection for water
        if (id == 20000)
            reflection.a = smoothstep(0.0, 1.0, reflection.a);

        // blindness
        float blindnessFogFactor = getBlindnessFactor(worldSpacePosition, blindnessRange);
        reflection.a = mix(reflection.a, 0.0, blindnessFogFactor * blindness);
        // darkness
        float darknessFogFactor = getBlindnessFactor(worldSpacePosition, darknessRange);
        reflection.a = mix(reflection.a, 0.0, darknessFogFactor * darknessFactor);

        // apply reflection
        color.rgb = mix(color.rgb, reflection.rgb, reflection.a);
    #endif

    // -- fog -- //
    foggify(worldSpacePosition, color.rgb, emissivness);
    // blindness
    doBlindness(worldSpacePosition, color.rgb, emissivness);

    // gamma correct
    color.rgb = linearToSRGB(color.rgb);

    // blending transition between classic terrain & DH terrain
    #ifdef DISTANT_HORIZONS
        vec3 playerSpacePosition = worldToPlayer(unanimatedWorldPosition);
        float cylindricDistance = max(length(playerSpacePosition.xz), abs(playerSpacePosition.y));
        float dhBlend = smoothstep(0.5*far, far, cylindricDistance);
        dhBlend = pow(dhBlend, 5.0);
        float dither = pseudoRandom(uv + frameTimeCounter / 3600.0);
        if (dhBlend > dither) discard;
    #endif

    // -- buffers -- //
    colorData = vec4(color);
    normalData = encodeNormal(normal);
    #ifdef TRANSPARENT
        lightAndMaterialData = vec4(0.0, emissivness, 0.0, pow(transparency, 0.25));
    #else
        lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, reflectance);
    #endif
}
