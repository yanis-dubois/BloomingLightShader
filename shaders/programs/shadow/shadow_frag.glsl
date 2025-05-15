#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/animation.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec4 clipSpacePosition;
in vec2 textureCoordinate; // immuable block & item
flat in int id;

// results
/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 shadowColor;
layout(location = 1) out vec4 lightShaft;

void main() {
    // retrieve data
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.rgb;
    float transparency = textureColor.a;
    vec3 tint = additionalColor.rgb;
    vec3 color = albedo * tint;
    vec3 lightShaftColor = id==20000 ? tint : color;

    // special case
    if (id == 20010) transparency = clamp(transparency, 0.2, 0.75); // uncolored glass
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;

    #if (VOLUMETRIC_LIGHT_TYPE > 0 && UNDERWATER_LIGHTSHAFT_TYPE > 0) || WATER_CAUSTIC_TYPE > 0
        vec3 worldSpacePosition = shadowClipToWorld(clipSpacePosition);
    #endif

    // underwater light shaft animation
    float lightShaftIntensity = transparency;
    #if VOLUMETRIC_LIGHT_TYPE > 0 && UNDERWATER_LIGHTSHAFT_TYPE > 0
        #if UNDERWATER_LIGHTSHAFT_TYPE == 1
            float noise = doWaterLightShaftAnimation(0.0, worldSpacePosition);
        #else
            float noise = doWaterLightShaftAnimation(frameTimeCounter, worldSpacePosition);
        #endif

        lightShaftIntensity += noise;
    #endif

    #if WATER_CAUSTIC_TYPE > 0
        if (id==20000) {
            // calculate the caustic factor
            #if WATER_CAUSTIC_TYPE == 1
                float causticFactor = getLightness(albedo);
                causticFactor = pow(causticFactor, 4.0);
                causticFactor = smoothstep(0.0, 0.6, causticFactor);
                causticFactor = pow(causticFactor, 1.5);
                causticFactor = smoothstep(0.0, 1.0, causticFactor);
            #else
                vec3 pos = floor((worldSpacePosition + 0.001) * 16.0) / 16.0 + 1.0/32.0;
                float causticFactor = doWaterCausticAnimation(frameTimeCounter, pos);
            #endif

            // apply a gradient based on the tint
            vec3 caustic = causticFactor * mix(tint, mix(saturate(tint, 2.0), vec3(1.0), 0.5 * causticFactor), causticFactor);
            // post treatment on color
            caustic = clamp(caustic * 1.5, 0.0, 1.0);
            caustic = smoothstep(0.0, 0.9, caustic);

            // apply the caustic
            color = caustic;
        }
    #endif

    // write buffers
    shadowColor = vec4(color, transparency);
    lightShaft = vec4(lightShaftColor, lightShaftIntensity);
}
