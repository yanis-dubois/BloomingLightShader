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
in vec4 additionalColor; // albedo of : foliage, water, particules
in vec3 Vnormal;
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
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    float transparency = textureColor.a;
    vec3 normal = Vnormal;

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
    getMaterialData(gtexture, id, normal, midBlock, albedo, smoothness, reflectance, emissivness, ambient_occlusion);  
    // opaque or transparent pass
    #ifdef TRANSPARENT
        bool isTransparent = true;
    #else
        bool isTransparent = false;
    #endif

    // normal
    #ifdef PARTICLE 
        normal = -normalize(playerLookVector);
    #endif
    // animated normal
    #if VERTEX_ANIMATION == 2
        if (isAnimated(id) && smoothness > 0.5) {
            mat3 TBN = generateTBN(normal);
            vec3 tangent = TBN[0] / 16.0;
            vec3 bitangent = TBN[1] / 16.0;

            vec3 actualPosition = doAnimation(id, frameTimeCounter, unanimatedWorldPosition, midBlock, ambientSkyLightIntensity);
            vec3 tangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + tangent, midBlock, ambientSkyLightIntensity);
            vec3 bitangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + bitangent, midBlock, ambientSkyLightIntensity);

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

    // glowing particles
    #ifdef PARTICLE
        // is glowing particle ?
        bool isGray = (albedo.r - albedo.g)*(albedo.r - albedo.g) + (albedo.r - albedo.b)*(albedo.r - albedo.b) + (albedo.b - albedo.g)*(albedo.b - albedo.g) < 0.05;
        bool isUnderwaterParticle = (albedo.r == albedo.g && albedo.r - 0.5 * albedo.b < 0.06);
        bool isWaterParticle = (albedo.b > 1.15 * (albedo.r + albedo.g) && albedo.g > albedo.r * 1.25 && albedo.g < 0.425 && albedo.b > 0.75);
        if (getLightness(textureColor.rgb) > 0.8 && !isGray && !isWaterParticle && !isUnderwaterParticle) {
            ambient_occlusion = 1.0;
            emissivness = 1.0;
            albedo *= 1.5;
        }
    #endif

    // light animation
    if (LIGHT_EMISSION_ANIMATION == 1 && emissivness > 0.0) {
        float noise = doLightAnimation(id, frameTimeCounter, unanimatedWorldPosition);
        emissivness -= noise;
    }

    // -- apply lighting -- //
    albedo = SRGBtoLinear(albedo);
    vec4 color = doLighting(gl_FragCoord.xy, albedo, transparency, normal, worldSpacePosition, unanimatedWorldPosition, smoothness, reflectance, 1.0, ambientSkyLightIntensity, blockLightIntensity, emissivness, ambient_occlusion, isTransparent);

    // -- reflection on transparent material -- //
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        vec4 reflection = doReflection(colortex4, colortex5, depthtex1, uv, depth, color.rgb, normal, ambientSkyLightIntensity, smoothness, reflectance);
        color.rgb = mix(color.rgb, reflection.rgb, reflection.a);
    #endif

    // -- fog -- //
    foggify(worldSpacePosition, color.rgb, emissivness);

    // gamma correct
    color.rgb = linearToSRGB(color.rgb);

    // -- buffers -- //
    colorData = vec4(color);
    normalData = encodeNormal(normal);
    lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, reflectance);
}
