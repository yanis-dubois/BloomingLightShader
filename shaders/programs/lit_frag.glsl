#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules albedo
in vec3 normal;
in vec2 textureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
in vec3 viewSpacePosition;
flat in int id;

// results
/* RENDERTARGETS: 0,1,2,3,4,5,6,7 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightAndTypeData;
layout(location = 3) out vec4 transparentAlbedoData;
layout(location = 4) out vec4 transparentNormalData;
layout(location = 5) out vec4 transparentLightData;
layout(location = 6) out vec4 opaquePBRData;
layout(location = 7) out vec4 transparentPBRData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    float transparency = textureColor.a;
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

    /* PBR */
    vec3 pbr = vec3(0);
    if (10000 <= id && id < 20000) pbr.x = 1;
    if (20000 <= id && id < 30000) pbr.y = 1;
    if (30000 <= id) pbr.z = 1;

    /* buffers */
    #ifdef TRANSPARENT
        transparentAlbedoData = vec4(albedo, transparency);
        transparentNormalData = vec4(encodedNormal, 1);
        transparentLightData = vec4(blockLightIntensity, ambiantSkyLightIntensity, type, 1);
        transparentPBRData = vec4(pbr, 1); // TODO
    #else
        opaqueAlbedoData = vec4(albedo, transparency);
        opaqueNormalData = vec4(encodedNormal, 1);
        opaqueLightAndTypeData = vec4(blockLightIntensity, ambiantSkyLightIntensity, type, 1);
        opaquePBRData = vec4(pbr, 1); // TODO
    #endif
}
