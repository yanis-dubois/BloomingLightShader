#version 140
#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

// attribute
in vec4 starData; //rgb = star color, a = flag for weather or not this pixel is a star.

// function
float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

vec3 screenToView(vec3 screenPos) {
	vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
	vec4 tmp = gbufferProjectionInverse * ndcPos;
	return tmp.xyz / tmp.w;
}

// results
/* RENDERTARGETS: 0,2,3,5 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueLightAndTypeData;
layout(location = 2) out vec4 transparentAlbedoData;
layout(location = 3) out vec4 transparentLightAndTypeData;

void main() {
	/* albedo */
	vec3 albedo = vec3(0);
	if (starData.a > 0.5) {
		albedo = starData.rgb;
	} else {
		vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1));
		albedo = calcSkyColor(normalize(pos));
	}
	
	/* type */
	float type = 0; // basic=0

	/* buffers */
    // write opaque buffers
    opaqueAlbedoData = vec4(albedo, 1);
    opaqueLightAndTypeData = vec4(0, 0, type, 1);
}
