#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"

// attribute
in vec4 starData;

// results
/* RENDERTARGETS: 0,2,3 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueLightData;
layout(location = 2) out vec4 opaqueMaterialData;

void main() {
	vec3 albedo = vec3(0);
	float transparency = 0;
	float emissivness = 0;

	vec3 viewSpacePosition = screenToView(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 0.99999);
	vec3 eyeSpacePosition = mat3(gbufferModelViewInverse) * viewSpacePosition;

	#if SKY_TYPE == 1
		// sky & stars
		albedo = getSkyColor(eyeSpacePosition);
	#else
		// stars
		if (starData.a > 0.5) {
			transparency = 1;
			albedo = starData.rgb;
			emissivness = getLightness(SRGBtoLinear(albedo) * 2);
		} 
		// sky
		else {
			albedo = getVanillaSkyColor(eyeSpacePosition);
		}
	#endif

	/* buffers */
    opaqueAlbedoData = vec4(albedo, transparency);
	opaqueLightData = vec4(0, 0, emissivness, 1);
    opaqueMaterialData = vec4(typeBasic, 0, 0, 1);
}
