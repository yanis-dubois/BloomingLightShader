// uniforms
uniform sampler2D shadowtex0; // all shadow
uniform sampler2D shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color

const float bias = 0.002; // 0.002

// makes shadows near to the player higher resolution than ones far from him
vec3 distortShadowClipPosition(vec3 shadowClipPosition) {
    // distance from the player in shadow clip space
    float distortionFactor = length(shadowClipPosition.xy); 
    // very small distances can cause issues so we add this to slightly reduce the distortion
    distortionFactor += 0.1; 

    // distort
    shadowClipPosition.xy /= distortionFactor;
    // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
    shadowClipPosition.z *= 0.5; 

    return shadowClipPosition;
}

vec4 distortAndBiasShadowClipPosition(vec4 shadowClipPosition) {
    // apply bias
    shadowClipPosition.z -= bias; 
    // apply distortion
    shadowClipPosition.xyz = distortShadowClipPosition(shadowClipPosition.xyz);

    return shadowClipPosition;
}

// say if a pixel is in shadow and apply a shadow color to it if needed
vec4 getShadow(vec3 shadowScreenPosition) {
    float isInShadow = step(shadowScreenPosition.z, shadow2D(shadowtex0, shadowScreenPosition.xy).r);
    float isntInColoredShadow = step(shadowScreenPosition.z, shadow2D(shadowtex1, shadowScreenPosition.xy).r);
    vec4 shadowColor = shadow2D(shadowcolor0, shadowScreenPosition.xy);

    vec4 shadow = vec4(vec3(1), 0);
    if (isInShadow == 0) {
        if (isntInColoredShadow == 0) {
            shadow = vec4(vec3(0), 1);
        } else {
            shadow = shadowColor;
        }
    }

    return shadow;
}

// get shadow from shadow clip position
vec4 getShadow(vec4 shadowClipPosition) {
    shadowClipPosition = distortAndBiasShadowClipPosition(shadowClipPosition);
    vec3 shadowScreenPosition = shadowClipToShadowScreen(shadowClipPosition);

    return getShadow(shadowScreenPosition);
}

// blur shadow by calling getShadow around actual pixel and average the results
vec4 getSoftShadow(vec2 uv, float depth, mat4 gbufferProjectionInverse, mat4 gbufferModelViewInverse) {
    // no shadows
    if (SHADOW_TYPE == 0) return vec4(0);

    // space conversion
    vec3 playerPosition = screenToPlayer(uv, depth);
    vec4 shadowClipPosition = playerToShadowClip(playerPosition);

    // hard shadowing
    if (SHADOW_SOFTNESS <= 0 || SHADOW_QUALITY <= 0) {
        return getShadow(shadowClipPosition);
    }

    // distant shadows are smoother
    float distanceToPlayer = distance(vec3(0), playerPosition);
    float blend = map(distanceToPlayer, 0, startShadowDecrease, 1, 20);

    float range = SHADOW_SOFTNESS / 2; // how far away from the original position we take our samples from
    range *= blend;
    float increment = range / SHADOW_QUALITY; // distance between each sample

    vec4 shadowAccum = vec4(0.0); // sum of all shadow samples
    int samples = 0;

    // stochastic shadows (faster but add noise)
    if (SHADOW_TYPE == 1) {
        for (int i=0; i<SHADOW_QUALITY*SHADOW_QUALITY; ++i) {
            // get noise
            vec2 seed = uv + i + (float(frameCounter)/720719.0);
            float zeta1 = pseudoRandom(seed);
            float zeta2 = pseudoRandom(seed + 0.5);
            float theta = zeta1 * 2*PI;
            float radius = range * sqrt(zeta2);
            float x = radius * cos(theta);
            float y = radius * sin(theta);
            
            // offset
            vec2 offset = vec2(x, y); // apply random rotation to offset
            offset /= shadowMapResolution; // divide by the resolution so offset is in terms of pixels

            vec4 offsetShadowClipPosition = shadowClipPosition + vec4(offset, 0.0, 0.0); // add offset
            shadowAccum += getShadow(offsetShadowClipPosition); // take shadow sample
            samples++;
        }
    } 
    // classic shadows (without noise but slower)
    else {
        // get noise
        float noise = pseudoRandom(uv);
        float theta = noise * 2*PI;
        float cosTheta = cos(theta);
        float sinTheta = sin(theta);
        // rotation matrix
        mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
 
        for (float x = -range; x <= range; x += increment) {
            for (float y = -range; y <= range; y += increment) {
                vec2 offset = rotation * vec2(x, y); // apply random rotation to offset
                offset /= shadowMapResolution; // divide by the resolution so offset is in terms of pixels
                vec4 offsetShadowClipPosition = shadowClipPosition + vec4(offset, 0.0, 0.0); // add offset
                shadowAccum += getShadow(offsetShadowClipPosition); // take shadow sample
                samples++;
            }
        }
    }
    
    return shadowAccum / float(samples); // divide sum by count, getting average shadow
}
