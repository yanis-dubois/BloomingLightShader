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
    #ifdef TERRAIN
        if (0 < blockEntityId && blockEntityId < 65535) id = blockEntityId;
    #endif

    // set position
    worldSpacePosition = gl_Vertex.xyz + cameraPosition;
    unanimatedWorldPosition = worldSpacePosition;
    gl_Position = ftransform();

    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);

    #ifdef WEATHER
        vec2 seed = vec2(floor(worldSpacePosition.x), floor(worldSpacePosition.z));
        float amplitude = 0.5;
        float noiseX = amplitude * pseudoRandom(seed.xy) - amplitude;
        float noiseZ = amplitude * pseudoRandom(seed.yx) - amplitude;
        worldSpacePosition.x += noiseX;
        worldSpacePosition.z += noiseZ;
        vec3 viewSpacePosition = worldToView(worldSpacePosition);
        gl_Position = gl_ProjectionMatrix * vec4(viewSpacePosition, 1); // to clip space
    #endif

    // update position if animated
    midBlock = at_midBlock;
    #if VERTEX_ANIMATION > 0
        if (isAnimated(id)) {
            worldSpacePosition = doAnimation(id, frameTimeCounter, worldSpacePosition, midBlock);
            vec3 viewSpacePosition = worldToView(worldSpacePosition);
            gl_Position = gl_ProjectionMatrix * vec4(viewSpacePosition, 1); // to clip space
        }
    #endif

    #if defined TERRAIN && TAA_TYPE > 1
        gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
    #endif
}
