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
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 shadowColor0;

void main() {
    /* texture value */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    float transparency = textureColor.a;
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    if (id == 20010) transparency = clamp(transparency, 0.2, 0.75); // uncolored glass
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;

    #if WATER_CAUSTIC_TYPE > 0
        if (SHADOW_WATER_ANIMATION == 1 && id==20000) {
            #if WATER_CAUSTIC_TYPE == 1
                float causticFactor = getLightness(albedo);
                causticFactor = smoothstep(0.0, 0.6, causticFactor);
                causticFactor = pow(causticFactor, 4.0);
                causticFactor = smoothstep(0.0, 0.4, causticFactor);
                causticFactor = pow(causticFactor, 1.5);
            #else
                vec3 worldSpacePosition = shadowClipToWorld(clipSpacePosition);
                vec3 pos = floor((worldSpacePosition + 0.001) * 16.0) / 16.0 + 1.0/32.0;
                float causticFactor = doShadowWaterAnimation(frameTimeCounter, pos);
            #endif

            vec3 caustic = additionalColor.rgb * causticFactor;
            caustic = smoothstep(0.0, 0.9, caustic);
            caustic = clamp(caustic * 1.5, 0.0, 1.0);

            transparency -= 0.33 * causticFactor;
            albedo = caustic;
        }
    #endif

    shadowColor0 = vec4(albedo, transparency);
}
