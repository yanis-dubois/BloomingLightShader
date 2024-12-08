#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules albedo
in vec2 textureCoordinate; // immuable block & item albedo
in vec2 typeData;

// results
/* RENDERTARGETS: 0,1,2,3,4,5 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightAndTypeData;
layout(location = 3) out vec4 transparentAlbedoData;
layout(location = 4) out vec4 transparentNormalData;
layout(location = 5) out vec4 transparentLightData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;
    
    /* type */
    float type = 0; // glowing=0

    #ifdef BEACON_BEAM
    type = 0;
    transparency = 0.8;
    #endif

    /* buffers */
    transparentAlbedoData = vec4(albedo.xyz, transparency);
    transparentNormalData = vec4(0, 0, 1, 1);
    transparentLightData = vec4(0, 0, type, 1);
}
