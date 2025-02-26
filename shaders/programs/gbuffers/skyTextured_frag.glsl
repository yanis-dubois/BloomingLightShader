#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item

// results
/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 colorData;
layout(location = 2) out vec4 lightAndMaterialData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    // transparency
    float transparency = mix(1.0, 0.5, rainStrength);
    if (transparency < alphaTestRef) discard;

    // frag position
    vec3 viewSpacePosition = screenToView(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0);
    vec3 eyeSpaceFragmentPosition = normalize(mat3(gbufferModelViewInverse) * viewSpacePosition);
    vec3 eyeSpaceSunPosition = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 eyeSpaceMoonPosition = normalize(mat3(gbufferModelViewInverse) * moonPosition);
    float VdotS = dot(eyeSpaceFragmentPosition, eyeSpaceSunPosition);
    float VdotX = dot(eyeSpaceFragmentPosition, eastDirection);

    #if SKY_TYPE == 1
        // polar coord of sun, moon & frag
        vec3 polarFragmentPosition = cartesianToPolar(eyeSpaceFragmentPosition);
        vec3 polarObjectPosition = VdotS > 0.0 ? cartesianToPolar(eyeSpaceSunPosition) : cartesianToPolar(eyeSpaceMoonPosition);
        float radius = VdotS > 0.0 ? 0.075 : 0.05;

        // cut sun & moon glare
        if (distanceInf(polarFragmentPosition.xy, polarObjectPosition.xy) > radius) {
            discard;
        }
        // avoid drawing of sun & moon in the bottom of the sky
        if (VdotX < 0.9 && eyeSpaceFragmentPosition.y < 0.08) {
            discard;
        }

        float emissivness = 1.0;
    #else
        float emissivness = getLightness(albedo);
    #endif

    // adapt emissivness with moon phase
    //if (VdotS < 0.0)
    //    emissivness *= getMoonPhase();

    /* buffers */
    colorData = vec4(albedo, transparency);
    lightAndMaterialData = vec4(0.0, emissivness, 0.0, transparency);
}
