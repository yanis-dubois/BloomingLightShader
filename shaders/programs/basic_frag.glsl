#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item
in vec2 typeData;

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

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;
    
    /* type */
    float type = 0; // basic=0

    #ifdef BEACON_BEAM
    albedo *= 1.25;
    transparency = 0.5;
    #endif

    /* buffers */
    #ifdef GLOWING
        transparentAlbedoData = vec4(albedo, transparency);
        transparentMaterialData = vec4(type, 0, 0, 1);
    #else
        opaqueAlbedoData = vec4(albedo, transparency);
        opaqueMaterialData = vec4(type, 0, 0, 1);
    #endif
}
