#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/animation.glsl"

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
// gl_MultiTexCoord2.xy - lightmap coordinate
in vec4 at_tangent;
in vec3 mc_Entity;
in vec3 at_midBlock;

// results
out vec4 additionalColor;
out vec3 normal;
out vec3 viewSpacePosition;
out vec3 unanimatedWorldPosition;
out vec3 midBlock;
out vec2 textureCoordinate;
out vec2 lightMapCoordinate;
flat out int id;

void main() {
    // color & light infos //
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    additionalColor = gl_Color;
    //additionalColor = vec4((gl_Vertex.xyz + at_midBlock)/16, 1);

    // geometry infos //
    normal = normalize(gl_NormalMatrix * gl_Normal);
    // from view to world space
    normal = mat3(gbufferModelViewInverse) * normal;

    id = int(mc_Entity.x);
    
    // depth
    vec4 viewPosition = (gl_ModelViewMatrix * gl_Vertex); // from player to view space
    viewSpacePosition = viewPosition.xyz;

    gl_Position = ftransform();

    unanimatedWorldPosition = gl_Vertex.xyz + cameraPosition;

    // vertex movement (see later)
    vec3 objectPosition = gl_Vertex.xyz + at_midBlock;
    midBlock = at_midBlock;
    if (ANIMATION==1 && isAnimated(id)) {
        objectPosition = gl_Vertex.xyz + at_midBlock;
        vec4 worldSpacePosition = ( (gbufferModelViewInverse) * viewPosition) + vec4(cameraPosition, 0);

        worldSpacePosition.xyz = doAnimation(id, float(worldTime), worldSpacePosition.xyz);

        viewPosition = (gbufferModelView * (worldSpacePosition - vec4(cameraPosition, 0)));
        viewSpacePosition = viewPosition.xyz;

        gl_Position = gl_ProjectionMatrix * viewPosition; // to clip space
    }
}
