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
out mat3 TBN;
out vec4 additionalColor;
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
    // normal
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    normal = mat3(gbufferModelViewInverse) * normal; // from view to world space
    // tangent
    vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    tangent = mat3(gbufferModelViewInverse) * tangent; // from view to world space
    // bitangent
    vec3 bitangent = cross(tangent, normal) * at_tangent.w;
    TBN = mat3(tangent, bitangent, normal);

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

    // remapped midBlock coordinates
    midBlock = at_midBlock;
    midBlock /= 64.0; // from [32;-32] to [0.5;-0.5] 
    midBlock.y = -1.0 * midBlock.y + 0.5; // from [0.5;-0.5] to [0;1]

    // update position if animated
    #if VERTEX_ANIMATION > 0
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
