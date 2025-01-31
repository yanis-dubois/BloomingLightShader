#version 140

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"

out vec3 skyLightColor;

out vec2 uv;

void main() {
    /* attributes infos */
    // light colors
    skyLightColor = getSkyLightColor();

    /* vertex infos */
    gl_Position = ftransform();
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
