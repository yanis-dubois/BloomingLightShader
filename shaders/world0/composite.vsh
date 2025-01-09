#version 140

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/color.glsl"

out vec3 skyLightColor;
out vec3 blockLightColor;
out vec3 fog_color;
out float shadowDayNightBlend;
out float rainFactor;
out float fog_density;

out vec2 uv;

void main() {
    /* attributes infos */
    skyLightColor = getSkyLightColor();

    // shadow
    vec3 upDirection = vec3(0,1,0);
    vec3 sunLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunDirectionDotUp = dot(sunLightDirectionWorldSpace, upDirection);
    shadowDayNightBlend = cosThetaToSigmoid(abs(sunDirectionDotUp), 5.0, 50.0, 0.55);

    // emissive block color
    blockLightColor = getBlockLightColor();

    // rain
    rainFactor = max(1-rainStrength, 0.05);

    // fog
    fog_color = SRGBtoLinear(fogColor);
    fog_density = mix(0.6, 1.8, rainStrength);
    // fog_density += mix(0, 0.5, rainfall); // sucks because of abrupt transition

    /* vertex infos */
    gl_Position = ftransform();
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
