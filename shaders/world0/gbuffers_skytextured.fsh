#version 140
#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item

// results
/* RENDERTARGETS: 0,2,3 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueLightData;
layout(location = 2) out vec4 opaqueMaterialData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    // transparency
    float transparency = textureColor.a;
    transparency = mix(transparency, 0.5, rainStrength);
    if (transparency < alphaTestRef) discard;

    // frag position
    vec3 viewSpacePosition = screenToView(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1);
    vec3 eyeSpaceFragmentPosition = normalize(mat3(gbufferModelViewInverse) * viewSpacePosition);
    vec3 eyeSpaceSunPosition = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 eyeSpaceMoonPosition = normalize(mat3(gbufferModelViewInverse) * moonPosition);
    float VdotS = dot(eyeSpaceFragmentPosition, eyeSpaceSunPosition);

    #if SKY_TYPE == 1
        // polar coord of frag & sun/moon
        vec3 polarFragmentPosition = cartesianToPolar(eyeSpaceFragmentPosition);
        vec3 polarSunPosition = cartesianToPolar(eyeSpaceSunPosition);
        vec3 polarMoonPosition = cartesianToPolar(eyeSpaceMoonPosition);

        // cut sun glare
        if (VdotS > 0) {
            float radius = 0.075;
            if (distanceInf(polarFragmentPosition.xy, polarSunPosition.xy) > radius) {
                discard;
            }
            if (eyeSpaceFragmentPosition.y < 0)
                discard;
        } 
        // cut moon glare
        else {
            float radius = 0.05;
            if (distanceInf(polarFragmentPosition.xy, polarMoonPosition.xy) > radius) {
                discard;
            }
        }

        float emissivness = 1;
    #else
        float emissivness = getLightness(albedo);
    #endif

    // adapt emissivness with moon phase
    if (VdotS < 0)
        emissivness *= getMoonPhase();

    /* buffers */
    opaqueAlbedoData = vec4(albedo, transparency);
    opaqueLightData = vec4(0, 0, emissivness, transparency);
    opaqueMaterialData = vec4(typeBasic, 0, 0, transparency);
}
