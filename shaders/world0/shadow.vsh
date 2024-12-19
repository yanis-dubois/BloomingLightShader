#version 140

// includes
#include "/lib/common.glsl"
#include "/lib/shadow.glsl"

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
in vec3 mc_Entity;

// results
out vec4 additionalColor;
out vec2 textureCoordinate;
flat out int id;
out vec3 playerSpacePosition;

void main() {
    // get render attributes infos
    textureCoordinate = gl_MultiTexCoord0.xy;
    additionalColor = gl_Color;
    gl_Position = ftransform();

    id = int(mc_Entity.x);
    
    vec3 shadowViewPosition = (shadowProjectionInverse * gl_Position).xyz;
    playerSpacePosition = (shadowModelViewInverse * vec4(shadowViewPosition, 1.0)).xyz;

    // apply distortion to shadow map
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
    
}
