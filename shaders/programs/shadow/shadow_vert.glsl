// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/shadow.glsl"
#include "/lib/animation.glsl"

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
in vec3 mc_Entity;
in vec3 at_midBlock;
in vec4 mc_midTexCoord;

// results
out vec4 additionalColor;
out vec3 worldSpacePosition;
out vec2 textureCoordinate;
flat out int id;

void main() {
    // get render attributes infos
    textureCoordinate = gl_MultiTexCoord0.xy;
    additionalColor = gl_Color;

    // get data
    worldSpacePosition = shadowClipToWorld(ftransform());
    vec2 lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    id = -1;
    // block
    id = int(mc_Entity.x + 0.5);
    // block entity (chest, bed, bells, ...)
    if (0 < blockEntityId && blockEntityId < 65535) id = blockEntityId;
    // item or item entity (dropped item, held item by other entity (or in 3rd person) & armor)
    else if (0 < currentRenderedItemId && currentRenderedItemId < 65535) id = currentRenderedItemId;
    // entity (mobs, item frame, banner, ...)
    else if (0 < entityId && entityId < 65535) id = entityId;

    // update position if animated (except for water)
    #if ANIMATED_POSITION > 0
        if (isAnimated(id) && !isWater(id)) {
            // remapped midBlock coordinates
            vec3 midBlock = at_midBlock;
            midBlock /= 64.0; // from [32;-32] to [0.5;-0.5] 
            midBlock.y = -1.0 * midBlock.y + 0.5; // from [0.5;-0.5] to [0;1]

            float ambientSkyLightIntensity = lightMapCoordinate.y;
            worldSpacePosition = doAnimation(id, frameTimeCounter, worldSpacePosition, midBlock, ambientSkyLightIntensity);
        }
    #endif

    // add shadows to props at noon
    // if (isProps(id)) {
    //     vec3 normal = gl_NormalMatrix * gl_Normal;
    //     vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).xy; // middle of the actual face in the atlas space
    //     vec2 atlasMidToCorner = textureCoordinate - midCoord; // vector from the middle of the face to the actual corner (vertex) in the atlas space
    //     // slightly move bottom vertices (so props aren't perpendicluar to sun)
    //     if (atlasMidToCorner.y < 0.0) {
    //         worldSpacePosition += normal * 0.4;
    //     }
    // }

    gl_Position = worldToShadowClip(worldSpacePosition); // to shadow clip space

    // apply distortion to shadow map
    gl_Position.xyz = distortShadowClipPosition(gl_Position.xyz);
}
