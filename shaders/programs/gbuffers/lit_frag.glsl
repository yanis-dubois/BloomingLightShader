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
#if PBR_POM > 0
    #include "/lib/POM.glsl"
#endif

// uniforms
uniform sampler2D gtexture;

// PBR
uniform sampler2D normals;
uniform sampler2D specular;

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
in vec2 originalTextureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
in vec4 textureCoordinateOffset;
in vec2 localTextureCoordinate;
flat in int id;

// results
/* RENDERTARGETS: 0,1,4,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec3 normalData;
layout(location = 2) out vec4 reflectionData;
layout(location = 3) out vec4 lightAndMaterialData;

void main() {

    // fragment data
    vec2 uv = texelToScreen(gl_FragCoord.xy);
    float depth = gl_FragCoord.z;
    vec3 viewDirection = normalize(eyeCameraPosition - worldSpacePosition);

    // tbn data
    #ifndef PARTICLE
        vec3 tangent = TBN[0];
        vec3 bitangent = TBN[1];
        vec3 normal = TBN[2];

    // particle tbn tweak (every particles normal point to the light source)
    #else
        vec3 normal = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        vec3 tangent = vec3(0.0, 0.0, 1.0);
        vec3 bitangent = cross(tangent, normal);
    #endif

    // initialize normalmap & POM normal
    vec3 normalMap = normal;
    vec3 normalPOM = vec3(0.0);

    vec2 textureCoordinate = originalTextureCoordinate;
    #if !defined PARTICLE && PBR_TYPE > 0 && PBR_POM > 0
        float worldSpaceDistance = length(cameraPosition - worldSpacePosition);

        // POM only apply on object that are inside POM render distance
        if (worldSpaceDistance < PBR_POM_DISTANCE) {
            textureCoordinate = doPOM(gtexture, normals, TBN, viewDirection, localTextureCoordinate, textureCoordinateOffset, worldSpaceDistance, normalPOM);

            // if the ray hit the side of a pixel, it gets a new normal
            if (length(normalPOM) > 0.0) {
                normalPOM = TBN * normalPOM;
            }
        }
    #endif

    // color data
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 tint = additionalColor.rgb;
    vec3 albedo = textureColor.rgb * tint;
    float transparency = textureColor.a;

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
    float smoothness = 0.0, reflectance = 0.0, emissivness = 0.0, ambientOcclusion = 1.0, subsurfaceScattering = 0.0;
    // initialize specific material as end portal or glowing particles
    getSpecificMaterial(gtexture, id, textureColor.rgb, tint, albedo, emissivness, subsurfaceScattering);
    // update PBR values with my own custom data
    getCustomMaterialData(id, normal, midBlock, albedo, smoothness, reflectance, emissivness, ambientOcclusion, subsurfaceScattering);  
    // modify these PBR values if PBR textures are enable
    getPBRMaterialData(normals, specular, textureCoordinate, smoothness, reflectance, emissivness, ambientOcclusion, subsurfaceScattering);

    // animated normal
    #if ANIMATED_POSITION == 2 && defined REFLECTIVE
        if (isAnimated(id) && length(normalPOM) <= 0.001) {

            // sample noise function
            vec3 actualPosition = doAnimation(id, frameTimeCounter, unanimatedWorldPosition, midBlock, ambientSkyLightIntensity);
            vec3 tangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + tangent / 16.0, midBlock, ambientSkyLightIntensity);
            vec3 bitangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + bitangent / 16.0, midBlock, ambientSkyLightIntensity);

            // calcul derivative
            vec3 newTangent = normalize(tangentDerivative - actualPosition);
            vec3 newBitangent = normalize(bitangentDerivative - actualPosition);

            // get new normal from derivative
            vec3 newNormal = - normalize(cross(newTangent, newBitangent));
            if (dot(newNormal, normal) < 0.0) newNormal *= -1.0;

            // use the new normal if it's visible
            if (dot(viewDirection, newNormal) > 0.0) {
                normalMap = newNormal;
            }
        }
    #endif

    // jittering normal for water
    #if defined TERRAIN && PIXELATED_REFLECTION == 2
        if (isWater(id) && length(normalPOM) <= 0.001) {
            vec4 seed = texture2DLod(gtexture, textureCoordinate, 0).rgba;
            float zeta1 = pseudoRandom(seed), zeta2 = pseudoRandom(seed + 41.43291);
            mat3 animatedTBN = generateTBN(normalMap);

            // sampling data
            float roughness = clamp(pow(1.0 - smoothness, 2.0), 0.1, 0.4);
            roughness *= roughness;

            // view direction from view to tangent space
            vec3 voxelizedViewDirection = normalize(cameraPosition - voxelize(unanimatedWorldPosition));
            vec3 tangentSpaceViewDirection = transpose(animatedTBN) * voxelizedViewDirection;
            // sample normal & convert to view
            vec3 sampledNormal = sampleGGXVNDF(tangentSpaceViewDirection, roughness, roughness, zeta1, zeta2);

            normalMap = animatedTBN * sampledNormal;
        }
    #endif

    // -- normal map -- //
    #if !defined PARTICLE && PBR_TYPE > 0
        vec4 normalMapData = texture2D(normals, textureCoordinate);

        // only if normal texture is specified
        if (normalMapData.x + normalMapData.y > 0.001) {
            // retrieve normal map
            normalMapData.xy = normalMapData.xy * 2.0 - 1.0;
            normalMap = vec3(normalMapData.xy, sqrt(1.0 - min(dot(normalMapData.xy, normalMapData.xy), 1.0)));
            // avoid normal map to be too tilted
            if (normalMap.z <= 0.1) {
                normalMap.z = 0.1;
                normalMap = normalize(normalMap);
            }
            // convert to world space and combine with normal
            normalMap = TBN * normalMap;
            normalMap = mix(normal, normalMap, 0.75);

            // apply POM normals
            #if PBR_POM_NORMAL > 0
                if (length(normalPOM) > 0.0) {
                    normalMap = normalize(mix(normalMap, normalPOM, 0.5));
                }
            #endif

            // clamp non visible normal
            if (dot(normalMap, viewDirection) < 0.0) {
                normalMap = normalize(normalMap - viewDirection * dot(normalMap, viewDirection));
                // albedo = vec3(1,0,0);
            }
            // albedo = normalMap;
            // colorData = vec4(vec3(dot(normalMap, viewDirection)), 1); return;
            // colorData = vec4(viewDirection, 1); return;
            // colorData = vec4(screenToPlayer(uv, depth), 1); return;

            // normalMap = normal;
        }
    #endif

    // light animation
    #if ANIMATED_EMISSION > 0
        if (isAnimatedLight(id)) {
            float noise = doLightAnimation(id, frameTimeCounter, unanimatedWorldPosition);
            emissivness = max(emissivness - noise, 0.0);
        }
    #endif

    // -- apply lighting -- //
    albedo = SRGBtoLinear(albedo);
    vec4 color = doLighting(gl_FragCoord.xy, albedo, transparency, normal, tangent, bitangent, normalMap, worldSpacePosition, unanimatedWorldPosition, smoothness, reflectance, 1.0, ambientSkyLightIntensity, blockLightIntensity, emissivness, ambientOcclusion, subsurfaceScattering);

    // -- reflection on transparent material -- //
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        #if PIXELATED_REFLECTION > 0
            // avoid position glitche for animated material (like water)
            vec3 screenSpacePosition = worldToScreen((unanimatedWorldPosition));
        #else
            vec3 screenSpacePosition = vec3(uv, depth);
        #endif
        vec4 reflection = doReflection(colortex4, colortex5, depthtex1, screenSpacePosition.xy, screenSpacePosition.z, color.rgb, normalMap, ambientSkyLightIntensity, smoothness, reflectance);

        // tweak reflection for water
        if (id == 20000)
            reflection.a = smoothstep(0.0, 1.0, reflection.a);

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

    #ifdef HAND
        reflectance = 0;
        smoothness = 0;
    #endif

    // -- buffers -- //
    colorData = color;
    normalData = encodeNormal(normalMap);
    #ifdef TRANSPARENT
        lightAndMaterialData = vec4(0.0, emissivness, 0.0, pow(transparency, 0.25));
    #else
        lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, 1.0 - reflectance);
    #endif
}
