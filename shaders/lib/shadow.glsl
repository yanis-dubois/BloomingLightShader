// uniforms
uniform sampler2D shadowtex0; // all shadow
uniform sampler2D shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color

const float bias = 0.0; // 0.002

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
    shadowScreenPosition.xy = clamp(shadowScreenPosition.xy, 0.0, 1.0);
    float isInShadow = step(shadowScreenPosition.z, shadow2D(shadowtex0, shadowScreenPosition.xy).r);

    vec4 shadow = vec4(vec3(1.0), 0.0);
    if (isInShadow == 0.0) {
        float isntInColoredShadow = step(shadowScreenPosition.z, shadow2D(shadowtex1, shadowScreenPosition.xy).r);
        if (isntInColoredShadow == 0.0) {
            shadow = vec4(vec3(0.0), 1.0);
        } else {
            vec4 shadowColor = texture2D(shadowcolor0, shadowScreenPosition.xy);
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
vec4 getSoftShadow(vec2 uv, vec3 worldSpacePosition) {

    // no shadows
    #if SHADOW_TYPE == 0
        return vec4(0.0);
    #else

        // space conversion
        vec3 playerPosition = worldToPlayer(worldSpacePosition);
        vec4 shadowClipPosition = playerToShadowClip(playerPosition);

        // hard shadowing
        #if float(SHADOW_RANGE) <= 0.01 || SHADOW_SAMPLES < 1
            return getShadow(shadowClipPosition);

        // soft shadowing
        #else

            // distant shadows are smoother
            float distanceToPlayer = distance(vec3(0.0), playerPosition);
            float blend = map(distanceToPlayer, 0.0, startShadowDecrease, 1.0, 20.0);

            float range = SHADOW_RANGE; // how far away from the original position we take our samples from
            range *= blend; // increase range as the shadow is further away
            float samples = SHADOW_SAMPLES;
            float step_length = (2.0 * range) / samples; // distance between each sample

            vec4 shadowAccum = vec4(0.0); // sum of all shadow samples
            float count = 0.0;

            // stochastic shadows (random sampling)
            #if SHADOW_TYPE == 1
                for (float i=0; i<samples; ++i) {

                    // random offset by sampling disk area
                    vec2 seed = uv + i ;//+ frameTimeCounter;
                    vec2 offset = sampleDiskArea(seed);

                    // gaussian
                    #if SHADOW_KERNEL == 1
                        float weight = gaussian(offset.x, offset.y, 0.0, 0.5);
                    // box
                    #else
                        float weight = 1.0;
                    #endif

                    // divide by the resolution so offset is in terms of pixels
                    offset = offset * range / shadowMapResolution;
                    vec4 offsetShadowClipPosition = shadowClipPosition + vec4(offset, 0.0, 0.0);
                    shadowAccum += weight * getShadow(offsetShadowClipPosition); // take shadow sample
                    count += weight;
                }

            // classic shadows (convolution)
            #elif SHADOW_TYPE > 1
                #if SHADOW_TYPE == 2
                    // get noise
                    float noise = pseudoRandom(uv);
                    float theta = noise * 2*PI;
                    float cosTheta = cos(theta);
                    float sinTheta = sin(theta);
                    // rotation matrix
                    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
                #endif

                for (float x=-range; x<=range; x+=step_length) {
                    for (float y=-range; y<=range; y+=step_length) {
                        vec2 offset = vec2(x, y); 

                        // gaussian
                        #if SHADOW_KERNEL == 1
                            float weight = gaussian(offset.x / range, offset.y / range, 0.0, 0.5);
                        // box
                        #else
                            float weight = 1.0;
                        #endif

                        #if SHADOW_TYPE == 2
                            // apply random rotation to offset
                            offset = rotation * offset;
                        #endif

                        offset /= shadowMapResolution; // divide by the resolution so offset is in terms of pixels
                        vec4 offsetShadowClipPosition = shadowClipPosition + vec4(offset, 0.0, 0.0);
                        shadowAccum += weight * getShadow(offsetShadowClipPosition); // take shadow sample
                        count += weight;
                    }
                }
            #endif

            return shadowAccum / count;
        #endif
    #endif
}
