#version 140

// includes
#include "/lib/shadow.glsl"

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate

// results
out vec4 additionalColor;
out vec2 textureCoordinate;

void main() {
    // get render attributes infos
    textureCoordinate = gl_MultiTexCoord0.xy;
    additionalColor = gl_Color;
    gl_Position = ftransform();

    // apply distortion to shadow map
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}
