#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"
#include "/lib/animation.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules albedo
in vec3 normal;
in vec3 unanimatedWorldPosition;
in vec3 midBlock;
in vec3 worldSpacePosition;
in vec2 textureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
flat in int id;

// results
/* RENDERTARGETS: 0,1,2,3,4,5,6,7 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightData;
layout(location = 3) out vec4 opaqueMaterialData;
layout(location = 4) out vec4 transparentAlbedoData;
layout(location = 5) out vec4 transparentNormalData;
layout(location = 6) out vec4 transparentLightData;
layout(location = 7) out vec4 transparentMaterialData;

void getMaterialData(int id, vec3 albedo, out float smoothness, out float reflectance, out float emissivness, out float ambient_occlusion) {
    smoothness = 0;
    reflectance = 0;
    emissivness = 0;
    ambient_occlusion = 0;

    float n1 = isEyeInWater == 1 ? 1.33 : 1;

    // -- smoothness -- //
    // water
    if (id == 20000) {
        smoothness = 0.9;

        ambient_occlusion = 1;

        float n2 = isEyeInWater == 0 ? 1.33 : 1;
        reflectance = getReflectance(n1, n2);
    }
    // glass 
    else if (id == 20010 || id == 20011 || id == 20012 || id == 20013 || id == 20014) {
        smoothness = 0.95;
        ambient_occlusion = 1;
        reflectance = getReflectance(n1, 1.5);
    }
    // metal
    else if (id == 20020) {
        smoothness = 0.75;
        reflectance = getReflectance(n1, 3);
    }
    // polished
    else if (id == 20030 || id == 20031) {
        smoothness = 0.6;
        reflectance = getReflectance(n1, 1.4);
    }
    // specular
    else if (id == 20040) {
        smoothness = 0.4;
        reflectance = getReflectance(n1, 1.3);
    }
    // rough
    else if (id == 20050) {
        smoothness = 0.2;
        reflectance = getReflectance(n1, 1);
    }
    // emmissive and smooth
    else if (id == 30030) {
        smoothness = 0.95;
        reflectance = getReflectance(n1, 1.5);
    }

    // -- emmissive -- //
    if (id >= 30000) {
        emissivness = 1;
        emissivness = getLightness(albedo);
    }

    // -- subsurface & ao -- //
    if (10000 <= id && id < 20000) {
        // leaves
        if (isFoliage(id) || isSolidFoliage(id)) {
            ambient_occlusion = 1;
        }
        // sugar cane
        else if (isColumnSubsurface(id)) {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(vec2(0), objectSpacePosition.xz);
            ambient_occlusion = min(ambient_occlusion*5, 1);
        }
        // other foliage
        else {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(vec3(0), objectSpacePosition);
        }
    }
}

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    float transparency = textureColor.a;
    // tweak transparency
    if (id == 20010) transparency = clamp(transparency, 0.2, 0.75); // uncolored glass 0.36
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;
    // apply red flash when mob are hitted
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a); 

    /* normal */
    vec3 encodedNormal = encodeNormal(normal);
    #ifdef PARTICLE 
        encodedNormal = encodeNormal(normalize(cameraPosition - unanimatedWorldPosition));
    #endif

    /* depth */
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    
    /* light */
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2);
    float heldBlockLight = heldLightValue>1 ? max(1 - (distanceFromCamera / max(heldLightValue,1)), 0) : 0;
    float blockLightIntensity = max(lightMapCoordinate.x, heldBlockLight);
    float ambiantSkyLightIntensity = lightMapCoordinate.y;

    /* material data */
    float smoothness = 0, reflectance = 0, emissivness = 0, ambient_occlusion = 0;
    getMaterialData(id, albedo, smoothness, reflectance, emissivness, ambient_occlusion);
    ambient_occlusion = map(1 - ambient_occlusion, 0.0, 1.0, 0.5, 1.0);

    // generate normalmap if animated
    if (VERTEX_ANIMATION==2 && isAnimated(id) && smoothness>alphaTestRef) {
        mat3 TBN = generateTBN(normal);
        vec3 tangent = TBN[0] / 16.0;
        vec3 bitangent = TBN[1] / 16.0;

        vec3 actualPosition = doAnimation(id, frameTimeCounter, unanimatedWorldPosition, midBlock);
        vec3 tangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + tangent, midBlock);
        vec3 bitangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + bitangent, midBlock);

        vec3 newTangent = normalize(tangentDerivative - actualPosition);
        vec3 newBitangent = normalize(bitangentDerivative - actualPosition);

        vec3 newNormal = normalize(- cross(newTangent, newBitangent));
        if (dot(newNormal, normal) < 0) newNormal *= -1;

        vec3 viewDirection = normalize(cameraPosition - actualPosition);
        if (dot(viewDirection, newNormal) < 0) newNormal = normal;

        encodedNormal = encodeNormal(newNormal);
        distanceFromCamera = distance(cameraPosition, actualPosition);
    }

    /* type */
    float type = typeLit;
    #ifdef TRANSPARENT
        if (id == 20000) type = typeWater;
    #endif
    #ifdef PARTICLE
        type = typeParticle;
        ambient_occlusion = 1;
        emissivness = 1;
    #endif

    // light animation
    if (LIGHT_EMISSION_ANIMATION == 1 && emissivness > 0) {
        float noise = doLightAnimation(id, frameTimeCounter, unanimatedWorldPosition);
        emissivness -= noise;
    }

    /* buffers */
    #ifdef TRANSPARENT
        transparentAlbedoData = vec4(albedo, transparency);
        transparentNormalData = vec4(encodedNormal, 1);
        transparentLightData = vec4(blockLightIntensity, ambiantSkyLightIntensity, emissivness, 1);
        transparentMaterialData = vec4(type, smoothness, reflectance, 1);
    #else
        opaqueAlbedoData = vec4(albedo, transparency);
        opaqueNormalData = vec4(encodedNormal, 1);
        opaqueLightData = vec4(blockLightIntensity, ambiantSkyLightIntensity, emissivness, ambient_occlusion);
        opaqueMaterialData = vec4(type, smoothness, reflectance, 1);
    #endif
}
