#version 140

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
    // make close shadow high res and far one low res
    float distanceFromPlayer = length(gl_Position.xy);
    gl_Position.xy = gl_Position.xy / (0.1+distanceFromPlayer);
}
