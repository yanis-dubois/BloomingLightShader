#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform float near;
uniform float far;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// attributes
in vec4 additionalColor; // foliage, water, particules albedo
in vec3 normal;
in vec2 textureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
in vec3 viewSpacePosition;
in vec2 typeData;

// results
/* RENDERTARGETS: 0,1,2,3,4,5 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightAndTypeData;
layout(location = 3) out vec4 transparentAlbedoData;
layout(location = 4) out vec4 transparentNormalData;
layout(location = 5) out vec4 transparentLightAndTypeData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    // transparency 
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;

    /* normal */
    vec3 encodedNormal = (normal+1.)/2.;

    /* depth */
    float distanceFromCamera = distance(vec3(0), viewSpacePosition);
    
    /* light */
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2)*1.;
    float heldBlockLight = heldLightValue>1 ? max(1-(distanceFromCamera/max(heldLightValue,1)), 0) : 0;
    float blockLightIntensity = max(lightMapCoordinate.x, heldBlockLight);
    float ambiantSkyLightIntensity = lightMapCoordinate.y;

    /* type */
    float type = 1; // lit=1

    /* buffers */
    opaqueAlbedoData = vec4(albedo, transparency);
    opaqueNormalData = vec4(encodedNormal, 1);
    opaqueLightAndTypeData = vec4(blockLightIntensity, ambiantSkyLightIntensity, type, 1);
}
