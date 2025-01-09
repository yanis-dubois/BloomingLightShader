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
out vec3 worldSpacePosition;
out vec3 unanimatedWorldPosition;
out vec3 midBlock;
out vec2 textureCoordinate;
out vec2 lightMapCoordinate;
flat out int id;

void main() {
    /* color & light infos */
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    additionalColor = gl_Color;

    /* geometry infos */
    normal = normalize(gl_NormalMatrix * gl_Normal);
    // from view to world space
    normal = mat3(gbufferModelViewInverse) * normal;

    id = int(mc_Entity.x);

    // set position
    worldSpacePosition = gl_Vertex.xyz + cameraPosition;
    unanimatedWorldPosition = worldSpacePosition;
    gl_Position = ftransform();

    // update position if animated
    midBlock = at_midBlock;
    if (ANIMATION_TYPE>0 && isAnimated(id)) {
        worldSpacePosition = doAnimation(id, frameTimeCounter/3600.0, worldSpacePosition, midBlock);
        vec3 viewSpacePosition = worldToView(worldSpacePosition);
        gl_Position = gl_ProjectionMatrix * vec4(viewSpacePosition, 1); // to clip space
    }
}
