#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"

// attribute
in vec4 starData;

// results
/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec4 lightAndMaterialData;

void main() {
	vec3 albedo = vec3(0.0);
	float transparency = 0.0;
	float emissivness = 0.0;

	vec3 viewSpacePosition = screenToView(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0);
	vec3 eyeSpacePosition = viewToEye(normalize(viewSpacePosition));

	#if SKY_TYPE == 1
		// sky & stars
		albedo = getSkyColor(eyeSpacePosition, false, emissivness);
	#else
		// stars
		if (starData.a > 0.5) {
			transparency = 1.0;
			albedo = starData.rgb;
			emissivness = getLightness(SRGBtoLinear(albedo) * 5.0);
			emissivness = clamp(emissivness, 0.0, 1.0);
		} 
		// sky
		else {
			albedo = getVanillaSkyColor(eyeSpacePosition);
		}
	#endif

	// apply blindness effect
	vec3 worldSpacePosition = screenToWorld(texelToScreen(gl_FragCoord.xy), 1.0);
    doBlindness(worldSpacePosition, albedo, emissivness);

	// buffers
    colorData = vec4(albedo, transparency);
	lightAndMaterialData = vec4(0.0, emissivness, 0.0, 1.0);
}
