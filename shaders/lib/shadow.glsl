// uniforms
uniform sampler2D shadowtex0; // all shadow
uniform sampler2D shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

// makes shadows near to the player higher resolution than ones far from them
vec3 distortShadowClipPos(vec3 shadowClipPos){
    float distortionFactor = length(shadowClipPos.xy); // distance from the player in shadow clip space
    distortionFactor += 0.1; // very small distances can cause issues so we add this to slightly reduce the distortion

    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5; // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
    return shadowClipPos;
}

// say if a pixel is in shadow and apply a shadow color to it if needed
vec4 getShadow(vec3 shadowScreenPos) {
    float isInShadow = step(shadowScreenPos.z, texture2D(shadowtex0, shadowScreenPos.xy).r);
    float isntInColoredShadow = step(shadowScreenPos.z, texture2D(shadowtex1, shadowScreenPos.xy).r);
    vec4 shadowColor = texture2D(shadowcolor0, shadowScreenPos.xy);

    // shadow get colored if needed
    vec4 shadow = vec4(0);
    if (isInShadow == 0) {
        if (isntInColoredShadow == 0) {
            shadow = vec4(vec3(0), 1);
        } else {
            shadow = shadowColor;// shadowColor.rgb * (1-shadowColor.a);
        }
    }

    return shadow;
}

// blur shadow by calling getShadow around actual pixel and average results
vec4 getSoftShadow(vec2 uv, float depth, mat4 gbufferProjectionInverse, mat4 gbufferModelViewInverse) {
    // space conversion
    vec3 NDCPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

    if (SHADOW_SOFTNESS <= 0. || SHADOW_QUALITY <= 0.) {
        shadowClipPos.z -= 0.0015; // apply bias
        shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz); // apply distortion
        vec3 shadowNDCPos = shadowClipPos.xyz / shadowClipPos.w; // convert to NDC space
        vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
        return getShadow(shadowScreenPos);
    }

    const float range = SHADOW_SOFTNESS / 2; // how far away from the original position we take our samples from
    const float increment = range / SHADOW_QUALITY; // distance between each sample

    vec4 shadowAccum = vec4(0.0); // sum of all shadow samples
    int samples = 0;

    for (float x = -range; x <= range; x += increment) {
        for (float y = -range; y <= range; y += increment) {
            vec2 offset = vec2(x, y) / shadowMapResolution; // we divide by the resolution so our offset is in terms of pixels
            vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
            offsetShadowClipPos.z -= 0.0015; // apply bias
            offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
            vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
            vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
            shadowAccum += getShadow(shadowScreenPos); // take shadow sample
            samples++;
        }
    }
    
    return shadowAccum / float(samples); // divide sum by count, getting average shadow
}
