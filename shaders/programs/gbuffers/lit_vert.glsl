// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/animation.glsl"
#if TAA_TYPE > 1
    #include "/lib/jitter.glsl"
#endif

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
// gl_MultiTexCoord2.xy - lightmap coordinate
in vec4 at_tangent;
in vec3 mc_Entity;
in vec3 at_midBlock;
in vec4 mc_midTexCoord;

// results
out vec4 additionalColor;
out vec3 Vnormal;
out vec3 Vtangent;
out vec3 Vbitangent;
out vec3 worldSpacePosition;
out vec3 unanimatedWorldPosition;
out vec3 midBlock;
out vec2 originalTextureCoordinate;
out vec2 lightMapCoordinate;
out vec4 textureCoordinateOffset;
out vec2 localTextureCoordinate;
flat out int id;

void main() {
    /* color & light infos */
    originalTextureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    additionalColor = gl_Color;

    // POM info
    vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).xy; // middle of the actual face in the atlas space
    vec2 atlasMidToCorner = originalTextureCoordinate - midCoord; // vector from the middle of the face to the actual corner (vertex) in the atlas space
    localTextureCoordinate = sign(atlasMidToCorner) * 0.5 + 0.5; // local uv coordinates of the actual face
    textureCoordinateOffset.xy = abs(atlasMidToCorner) * 2.0; // length of the diagonal of the actual face in atlas space
    textureCoordinateOffset.zw = min(originalTextureCoordinate, midCoord - (atlasMidToCorner)); // coordinates in atlas space of the corner that have the (0,0) local uv coordinate

    id = int(mc_Entity.x);
    #if defined TERRAIN
        if (0 < blockEntityId && blockEntityId < 65535) id = blockEntityId;
    #elif defined ENTITY
        if (0 < currentRenderedItemId && currentRenderedItemId < 65535) id = currentRenderedItemId;
        else if (0 < entityId && entityId < 65535) id = entityId;
    #else
        if (0 < currentRenderedItemId && currentRenderedItemId < 65535) id = currentRenderedItemId;
        else if (0 < entityId && entityId < 65535) id = entityId;
        else if (0 < blockEntityId && blockEntityId < 65535) id = blockEntityId;
    #endif

    /* geometry infos */
    // normal
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 bitangent = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
    // from view to world space
    normal = mat3(gbufferModelViewInverse) * normal;
    tangent = mat3(gbufferModelViewInverse) * tangent;
    bitangent = mat3(gbufferModelViewInverse) * bitangent;
    #if defined TERRAIN && !defined BLOCK_ENTITY && !defined CUTOUT
        // TODO: we should invert the tangent of every block that are orientable (ex: wood log, barrel, deepslate, ...)
        // bitangent *= at_tangent.w;
    #endif
    Vnormal = normal;
    Vtangent = tangent;
    Vbitangent = bitangent;

    // set position
    worldSpacePosition = viewToWorld((gl_ModelViewMatrix * gl_Vertex).xyz);
    unanimatedWorldPosition = worldSpacePosition;
    gl_Position = ftransform();

    // remapped midBlock coordinates
    midBlock = at_midBlock;
    midBlock /= 64.0; // from [32;-32] to [0.5;-0.5] 
    midBlock.y = -1.0 * midBlock.y + 0.5; // from [0.5;-0.5] to [0;1]

    // update position if animated
    #if ANIMATED_POSITION > 0 && defined TERRAIN
        if (isAnimated(id)) {
            float ambientSkyLightIntensity = lightMapCoordinate.y;

            worldSpacePosition = doAnimation(id, frameTimeCounter, worldSpacePosition, midBlock, ambientSkyLightIntensity);
            vec3 viewSpacePosition = worldToView(worldSpacePosition);
            gl_Position = gl_ProjectionMatrix * vec4(viewSpacePosition, 1); // to clip space
        }
    #endif

    #if defined TERRAIN && TAA_TYPE > 1
        gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
    #endif
}
