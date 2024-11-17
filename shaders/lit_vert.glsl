// uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
// gl_MultiTexCoord2.xy - lightmap coordinate

// results
out vec4 additionalColor;
out vec3 viewSpacePosition;
out vec3 normal;
out vec2 textureCoordinate;
out vec2 lightMapCoordinate;

void main() {
    // color & light infos
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    additionalColor = gl_Color;

    // geometry infos
    normal = normalize(gl_NormalMatrix * gl_Normal);
    viewSpacePosition = (gl_ModelViewMatrix * gl_Vertex).xyz;

    // for vertex movement (see later)
    // vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex; // from object_space to ...
    // // wave transformations ...
    // gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

    gl_Position = ftransform();
}
