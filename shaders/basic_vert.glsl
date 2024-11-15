#version 120

// uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
// gl_MultiTexCoord2.xy - lightmap coordinate

// results
out vec4 additionalColor;
out vec3 viewSpacePosition;
out vec2 textureCoordinate;
out vec2 lightMapCoordinate;

void main() {
    // get attributes infos
    textureCoordinate = gl_MultiTexCoord0.xy;
    lightMapCoordinate = (1.*gl_MultiTexCoord2.xy / 256.) + (1./32.);
    additionalColor = gl_Color;

    viewSpacePosition = (gl_ModelViewMatrix * gl_Vertex).xyz;

    // for vertex movement (see later)
    // vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex; // from object_space to ...
    // // wave transformations ...
    // gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

    gl_Position = ftransform();
}
