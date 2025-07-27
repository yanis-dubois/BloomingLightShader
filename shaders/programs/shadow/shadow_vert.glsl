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

// results
out vec4 additionalColor;
out vec4 clipSpacePosition;
out vec2 textureCoordinate;
flat out int id;

void main() {
    // get render attributes infos
    textureCoordinate = gl_MultiTexCoord0.xy;
    additionalColor = gl_Color;
    gl_Position = ftransform();
    clipSpacePosition = gl_Position;

    id = -1;
    // block
    id = int(mc_Entity.x + 0.5);
    // block entity (chest, bed, bells, ...)
    if (0 < blockEntityId && blockEntityId < 65535) id = blockEntityId;
    // item or item entity (dropped item, held item by other entity (or in 3rd person) & armor)
    else if (0 < currentRenderedItemId && currentRenderedItemId < 65535) id = currentRenderedItemId;
    // entity (mobs, item frame, banner, ...)
    else if (0 < entityId && entityId < 65535) id = entityId;

    // update position if animated
    #if ANIMATED_POSITION > 0
        if (isAnimated(id)) {
            // set position
            vec3 worldSpacePosition = shadowClipToWorld(ftransform());
            vec2 lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

            // remapped midBlock coordinates
            vec3 midBlock = at_midBlock;
            midBlock /= 64.0; // from [32;-32] to [0.5;-0.5] 
            midBlock.y = -1.0 * midBlock.y + 0.5; // from [0.5;-0.5] to [0;1]

            float ambientSkyLightIntensity = lightMapCoordinate.y;
            worldSpacePosition = doAnimation(id, frameTimeCounter, worldSpacePosition, midBlock, ambientSkyLightIntensity);
            gl_Position = worldToShadowClip(worldSpacePosition); // to shadow clip space
        }
    #endif

    // apply distortion to shadow map
    gl_Position.xyz = distortShadowClipPosition(gl_Position.xyz);
}
