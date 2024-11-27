#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item
in vec2 typeData;

// results
/* RENDERTARGETS: 0,2,3,5,6 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 2) out vec4 opaqueLightAndTypeData;
layout(location = 3) out vec4 transparentAlbedoData;
layout(location = 5) out vec4 transparentLightAndTypeData;
layout(location = 6) out vec4 opaqueTypeData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    // transparency
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;
    
    /* type */
    float type = 0; // basic=0

    /* buffers */
    // write opaque buffers
    opaqueAlbedoData = vec4(albedo, transparency);
    opaqueLightAndTypeData = vec4(0, 0, type, 1);
    opaqueTypeData = vec4(typeData, 0, 1);
}
