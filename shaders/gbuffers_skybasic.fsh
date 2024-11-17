#version 140
#extension GL_ARB_explicit_attrib_location : enable

uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

in vec4 starData; //rgb = star color, a = flag for weather or not this pixel is a star.

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

/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 outColor1; //colortex1 - specular

void main() {
	if (starData.a > 0.5) {
		color = vec4(starData.rgb, 1.0);
	} else {
		vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
		vec3 albedo = calcSkyColor(normalize(pos));
		color = vec4(albedo, 1.0);
		outColor1 = vec4(vec3(0.0),1.0);
	}
}