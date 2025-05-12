// uniforms
uniform sampler2DShadow shadowtex0; // all shadow
uniform sampler2DShadow shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color
uniform sampler2D shadowcolor1; // light shaft color

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
vec4 sampleShadow(vec3 shadowScreenPosition, bool isLightShaft) {
    shadowScreenPosition.xy = clamp(shadowScreenPosition.xy, 0.0, 1.0);
    float shadow0 = shadow2D(shadowtex0, shadowScreenPosition.xyz).r;

    vec4 shadowColor = vec4(vec3(1.0), 0.0);
    if (shadow0 < 1.0) {
        float shadow1 = shadow2D(shadowtex1, shadowScreenPosition.xyz).r;
        if (shadow1 < 1.0) {
            shadowColor = vec4(vec3(shadow0), 1.0);
        } else {
            shadowColor = texture2D(isLightShaft ? shadowcolor1 : shadowcolor0, shadowScreenPosition.xy);
        }
    }

    return shadowColor;
}

// get shadow from shadow clip position
vec4 getShadow(vec4 shadowClipPosition, bool isLightShaft) {
    shadowClipPosition = distortAndBiasShadowClipPosition(shadowClipPosition);
    vec3 shadowScreenPosition = shadowClipToShadowScreen(shadowClipPosition);

    return sampleShadow(shadowScreenPosition, isLightShaft);
}

// blur shadow by calling getShadow around pixel and average the results
vec4 getSoftShadow(vec2 uv, vec3 worldSpacePosition) {

    // no shadows
    #if SHADOW_TYPE == 0
        return vec4(0.0);
    #else

        // space conversion
        vec3 playerSpacePosition = worldToPlayer(worldSpacePosition);
        vec4 shadowClipPosition = playerToShadowClip(playerSpacePosition);
        vec4 distortedShadowClipPosition = distortAndBiasShadowClipPosition(shadowClipPosition);
        vec3 shadowScreenPosition = shadowClipToShadowScreen(distortedShadowClipPosition);

        // hard shadowing
        #if SHADOW_SAMPLES < 1
            return getShadow(shadowClipPosition, false);
        #elif SHADOW_RANGE < 0.01
            return getShadow(shadowClipPosition, false);

        // soft shadowing
        #else

            // distant shadows are smoother because of distortion on shadow screen
            float range = SHADOW_RANGE; // how far away from the original position we take our samples from
            float samples = SHADOW_SAMPLES;
            float step_length = range / samples; // distance between each sample

            vec4 shadowAccum = vec4(0.0); // sum of all shadow samples
            float count = 0.0;

            // stochastic shadows (random sampling)
            #if SHADOW_TYPE == 1
                for (float i=0; i<samples; ++i) {

                    // random offset by sampling disk area
                    vec2 seed = uv + 0.23 * i;
                    float zeta1 = dithering(seed, SHADOW_DITHERING_TYPE);
                    float zeta2 = dithering(seed + 0.5, SHADOW_DITHERING_TYPE);
                    vec2 offset = sampleDiskArea(zeta1, zeta2);

                    // gaussian
                    #if SHADOW_KERNEL == 1
                        float weight = gaussian(offset.x, offset.y, 0.0, 0.5);
                    // box
                    #else
                        float weight = 1.0;
                    #endif

                    offset = offset * range / shadowMapResolution; // divide by the resolution so offset is in terms of uvs
                    vec3 offsetShadowScreenPosition = shadowScreenPosition + vec3(offset, 0.0);
                    shadowAccum += weight * sampleShadow(offsetShadowScreenPosition, false);
                    count += weight;
                }

            // classic shadows (convolution)
            #elif SHADOW_TYPE > 1
                #if SHADOW_TYPE == 2
                    // random rotation matrix
                    float noise = dithering(uv, SHADOW_DITHERING_TYPE);
                    mat2 rotation = randomRotationMatrix(noise);
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

                        offset /= shadowMapResolution; // divide by the resolution so offset is in terms of uvs
                        vec3 offsetShadowScreenPosition = shadowScreenPosition + vec3(offset, 0.0);
                        shadowAccum += weight * sampleShadow(offsetShadowScreenPosition, false);
                        count += weight;
                    }
                }
            #endif

            return shadowAccum / count;
        #endif
    #endif
}

// pixelated version of soft shadow
vec4 getSoftShadow(vec2 uv, vec3 worldSpacePosition, vec3 tangent, vec3 bitangent, float ambientSkyLightIntensity) {

    // no shadows
    #if SHADOW_TYPE == 0
        return vec4(0.0);

    // hard shadows
    #elif PIXELATED_SHADOW == 1
        vec3 playerSpacePosition = worldToPlayer(worldSpacePosition);
        vec4 shadowClipPosition = playerToShadowClip(playerSpacePosition);
        return getShadow(shadowClipPosition, false);

    // soft shadows
    #else
        float distanceToPlayer = distance(vec3(0.0), worldToPlayer(worldSpacePosition));

        // distant shadows are smoother
        vec3 playerSpacePosition = worldToPlayer(worldSpacePosition);
        vec4 shadowClipPosition = playerToShadowClip(playerSpacePosition);
        float shadowClipdistanceToPlayer = length(shadowClipPosition.xy);
        float blend = 1.0 + 10.0 * smoothstep(0.0, startShadowDecrease, distanceToPlayer);

        float range = 1.0; // how far away from the original position we take our samples from
        range *= blend;
        vec4 shadowAccum = vec4(0.0); // sum of all shadow samples
        float count = 0.0;

        // return the middle sample if it has no transparency and sky light is nul
        // avoid cave leaks while allowing water caustics deep underwater
        vec4 middleSampledShadow = vec4(0.0);
        if (ambientSkyLightIntensity < 0.01) {
            middleSampledShadow = getShadow(shadowClipPosition, false);

            if (middleSampledShadow.a > 0.9) {
                return middleSampledShadow;
            }
        }

        bool checker = false;
        checker = distanceToPlayer > 0.5 * startShadowDecrease;
        vec4 sampledShadow = vec4(0.0);
        for (float x=-range; x<=range; x+=range) {
            for (float y=-range; y<=range; y+=range) {
                if (checker) {
                    checker = false;
                    continue;
                }
                checker = true;

                vec2 offset = vec2(x, y);
                float weight = isInRange(offset, -0.1, 0.1) ? 1.0 : 0.5;

                // avoid to resample middle shadow
                if (middleSampledShadow.a > 0.0 && isInRange(offset, -0.1, 0.1)) {
                    sampledShadow = middleSampledShadow;
                }
                // sample shadow
                else {
                    vec3 offsetWorldSpacePosition = worldSpacePosition + offset.x / TEXTURE_RESOLUTION * tangent + offset.y / TEXTURE_RESOLUTION * bitangent;
                    playerSpacePosition = worldToPlayer(offsetWorldSpacePosition);
                    shadowClipPosition = playerToShadowClip(playerSpacePosition);
                    sampledShadow = getShadow(shadowClipPosition, false);
                }

                // add shadow contribution
                shadowAccum += weight * sampledShadow;
                count += weight;
            }
        }

        return shadowAccum / count;
    #endif
}
