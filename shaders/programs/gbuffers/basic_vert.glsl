// includes
#include "/lib/common.glsl"
#if TAA_TYPE > 1
    #include "/lib/jitter.glsl"
#endif

// results
out vec4 additionalColor;
out vec2 textureCoordinate;

void main() {
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    additionalColor = gl_Color;
    gl_Position = ftransform();
}
