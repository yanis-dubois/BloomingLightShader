// uniforms
uniform mat4 gbufferModelViewInverse;

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
// gl_MultiTexCoord2.xy - lightmap coordinate
in vec3 mc_Entity;

// results
out vec4 additionalColor;
out vec3 normal;
out vec3 viewSpacePosition;
out vec2 typeData;
out vec2 textureCoordinate;
out vec2 lightMapCoordinate;

void main() {
    // color & light infos //
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    additionalColor = gl_Color;

    // geometry infos //
    // normal
    normal = normalize(gl_NormalMatrix * gl_Normal);
    normal = mat3(gbufferModelViewInverse) * normal; // from view to world space

    typeData = mc_Entity.xy;
    
    // depth
    viewSpacePosition = (gl_ModelViewMatrix * gl_Vertex).xyz; // from object to view space

    // vertex movement (see later)

    gl_Position = ftransform();
}
