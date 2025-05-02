// includes
#include "/lib/common.glsl"
#include "/lib/space_conversion.glsl"
#if TAA_TYPE > 1
    #include "/lib/jitter.glsl"
#endif

// results
out vec4 additionalColor;
out vec3 worldSpacePosition;
out vec2 textureCoordinate;

void main() {
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    additionalColor = gl_Color;
    worldSpacePosition = viewToWorld((gl_ModelViewMatrix * gl_Vertex).xyz);
    gl_Position = ftransform();
}
