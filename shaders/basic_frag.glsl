#version 120

// uniforms
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec3 viewSpacePosition;
in vec2 textureCoordinate; // immuable block & item 
in vec2 lightMapCoordinate; // light map

// results
/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 outColor0;

void main() {
    // get texture value
    vec4 lightColor = texture2D(lightmap, lightMapCoordinate);
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    
    // manage transparency
    float transparency = textureColor.a;
    if (transparency < .1) {
        discard;
    }

    // calcul fragment color
    vec3 color = textureColor.rgb * additionalColor.rgb * lightColor.rgb;

    // add fog
    float distanceFromCamera = distance(vec3(0), viewSpacePosition);
    float minFogDistance = fogStart;
    float maxFogDistance = fogEnd;
    float fogBlend = clamp((distanceFromCamera - minFogDistance) / (maxFogDistance - minFogDistance), 0, 1);
    color = mix(color, fogColor, fogBlend);

    // combine color & transparency as result
    outColor0 = vec4(color, transparency);

    /** debug **/
    // outColor0 = vec4(vec3(fogBlend), 1);
}
