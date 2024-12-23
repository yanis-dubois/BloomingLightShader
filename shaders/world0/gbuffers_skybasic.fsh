#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#includes "/lib/common.glsl"
#includes "/lib/space_conversion.glsl"

// attribute
in vec4 starData; //rgb = star color, a = flag for weather or not this pixel is a star.

// function
float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz);
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

// results
/* RENDERTARGETS: 0,2,3 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueLightData;
layout(location = 2) out vec4 opaqueMaterialData;

void main() {
	float emissivness = 0;

	/* albedo */
	vec3 albedo = vec3(0);
	if (starData.a > 0.5) {
		albedo = starData.rgb;
		emissivness = 1;
	} else {
		vec3 pos = screenToView(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1);
		albedo = calcSkyColor(normalize(pos));
	}
	
	/* buffers */
    opaqueAlbedoData = vec4(albedo, 1);
	opaqueLightData = vec4(0, 0, emissivness, 1);
    opaqueMaterialData = vec4(typeBasic, 0, 0, 1);
}
