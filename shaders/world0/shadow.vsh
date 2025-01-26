#version 140

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/shadow.glsl"

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
in vec3 mc_Entity;

// results
out vec4 additionalColor;
out vec4 clipSpacePosition;
out vec2 textureCoordinate;
flat out int id;

void main() {
    // get render attributes infos
    textureCoordinate = gl_MultiTexCoord0.xy;
    additionalColor = gl_Color;
    gl_Position = ftransform();
    clipSpacePosition = gl_Position;

    id = int(mc_Entity.x);
    
    // apply distortion to shadow map
    gl_Position.xyz = distortShadowClipPosition(gl_Position.xyz);
}
