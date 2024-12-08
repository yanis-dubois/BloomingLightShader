#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item
in vec2 typeData;

// results
/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueLightAndTypeData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;

    /* type */
    float type = 0; // basic=0

    albedo = vec3(1,0,0);

    /* buffers */
    opaqueAlbedoData = vec4(albedo, 0.5);
    opaqueLightAndTypeData = vec4(0, 0, type, 1);
}
