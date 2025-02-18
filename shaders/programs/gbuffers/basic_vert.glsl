// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
in vec3 mc_Entity;

// results
out vec4 additionalColor;
out vec2 textureCoordinate;
out vec2 typeData;

void main() {
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    additionalColor = gl_Color;
    typeData = mc_Entity.xy;
    gl_Position = ftransform();
}
