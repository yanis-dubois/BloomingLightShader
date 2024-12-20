#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules albedo
in vec3 normal;
in vec3 viewSpacePosition;
in vec2 textureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
flat in int id;

// results
/* RENDERTARGETS: 0,1,2,3,4,5,6,7 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightData; // blockLightIntensity, ambiantSkyLightIntensity, emmissivness, type, smoothness, reflectance
layout(location = 3) out vec4 opaqueMaterialData;
layout(location = 4) out vec4 transparentAlbedoData;
layout(location = 5) out vec4 transparentNormalData;
layout(location = 6) out vec4 transparentLightData;
layout(location = 7) out vec4 transparentMaterialData;

vec3 getMaterialData(int id) {
    float smoothness = 0;
    float reflectance = 0;
    float emmissivness = 0;

    float n1 = isEyeInWater == 1 ? 1.33 : 1;

    // -- smoothness -- //

    // water
    if (id == 20000) {
        smoothness = 0.9;

        float n2 = isEyeInWater == 0 ? 1.33 : 1;
        reflectance = getReflectance(n1, n2);
    }
    // glass 
    else if (id == 20010 || id == 20011 || id == 20012 || id == 20013) {
        smoothness = 0.95;
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
        emmissivness = 1;
    }

    return vec3(smoothness, reflectance, emmissivness);
}

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    float transparency = textureColor.a;
    if (id == 20010) transparency = clamp(transparency, 0.36, 0.75); // uncolored glass
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;

    /* normal */
    vec3 encodedNormal = encodeNormal(normal);

    /* depth */
    float distanceFromCamera = distance(vec3(0), viewSpacePosition);
    
    /* light */
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2)*1.;
    float heldBlockLight = heldLightValue>1 ? max(1-(distanceFromCamera/max(heldLightValue,1)), 0) : 0;
    float blockLightIntensity = max(lightMapCoordinate.x, heldBlockLight);
    float ambiantSkyLightIntensity = lightMapCoordinate.y;

    /* type */
    float type = 1; // lit=1
    if (id == 20000) type = 0.95; // water

    /* material data */
    vec3 pbr = getMaterialData(id);
    float smoothness = pbr.x;
    float reflectance = pbr.y;
    float emmissivness = pbr.z;

    //// pbr debug 
    // if (10000 <= id && id < 20000) pbr.x = 1;
    // if (20000 <= id && id < 30000) pbr.y = 1;
    // if (30000 <= id) pbr.z = 1;

    /* buffers */
    #ifdef TRANSPARENT
        transparentAlbedoData = vec4(albedo, transparency);
        transparentNormalData = vec4(encodedNormal, 1);
        transparentLightData = vec4(blockLightIntensity, ambiantSkyLightIntensity, emmissivness, 1);
        transparentMaterialData = vec4(type, smoothness, reflectance, 1);
    #else
        opaqueAlbedoData = vec4(albedo, transparency);
        opaqueNormalData = vec4(encodedNormal, 1);
        opaqueLightData = vec4(blockLightIntensity, ambiantSkyLightIntensity, emmissivness, 1);
        opaqueMaterialData = vec4(type, smoothness, reflectance, 1);
    #endif
}
