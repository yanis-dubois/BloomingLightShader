#version 140

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/atmospheric.glsl"

out vec3 skyLightColor;
out vec3 blockLightColor;
out vec3 fog_color;
out float rainFactor;
out float fog_density;

out vec2 uv;

void main() {
    /* attributes infos */
    // light colors
    skyLightColor = getSkyLightColor_fast();
    blockLightColor = getBlockLightColor_fast();
    // rain - light attenuation factor
    rainFactor = max(1-rainStrength, 0.05);
    // fog
    fog_color = SRGBtoLinear(fogColor);
    fog_density = mix(0.6, 1.8, rainStrength);

    /* vertex infos */
    gl_Position = ftransform();
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
