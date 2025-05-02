// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#if TAA_TYPE > 1
    #include "/lib/jitter.glsl"
#endif

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
// gl_MultiTexCoord2.xy - lightmap coordinate

// results
out vec4 Valbedo;
out vec3 worldSpacePosition;
out vec3 Vnormal;
out vec2 lightMapCoordinate;
flat out int id;

void main() {
    /* color & light infos */
    lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    Valbedo = gl_Color;

    // normal
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    Vnormal = mat3(gbufferModelViewInverse) * normal; // from view to world space

    // id
    id = dhMaterialId;

    // set position
    worldSpacePosition = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz + cameraPosition;
    gl_Position = ftransform();

    // TAA
    #if TAA_TYPE > 1
        gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
    #endif
}
