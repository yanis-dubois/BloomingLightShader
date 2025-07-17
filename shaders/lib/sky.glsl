// -- sky box color -- //
// day colors
const vec3 dayDownColor = vec3(0.75, 0.95, 1.0);
const vec3 dayMiddleColor = vec3(0.48, 0.7, 1.0);
const vec3 dayTopColor = vec3(0.25, 0.5, 1.0);
// night colors
const vec3 nightDownColor = vec3(0.15, 0.13, 0.3);
const vec3 nightMiddleColor = vec3(0.07, 0.06, 0.15);
const vec3 nightTopColor = vec3(0.005, 0.005, 0.05);
// rainy colors
const vec3 rainyDownColor = vec3(0.55, 0.6, 0.7);
const vec3 rainyMiddleColor = vec3(0.35, 0.4, 0.45);
const vec3 rainyTopColor = vec3(0.2, 0.25, 0.3);
// sunset colors
const vec3 sunsetNearColor = vec3(1.0, 0.35, 0.1);
const vec3 sunsetDownColor = vec3(1.0, 0.5, 0.2);
const vec3 sunsetMiddleColor = vec3(0.8, 0.4, 0.6);
const vec3 sunsetTopColor = vec3(0.28, 0.32, 0.55);
const vec3 sunsetHighColor = vec3(0.15, 0.2, 0.5);
// end colors
const vec3 endColor = vec3(0.06, 0.045, 0.08);
// blindness 
const vec3 blindnessColor = vec3(0.0);

// vanilla 
vec3 getVanillaSkyColor(vec3 eyeSpacePosition) {
    #if defined OVERWORLD
        vec3 eyeSpaceViewDirection = normalize(eyeSpacePosition);
        float viewDotUp = dot(eyeSpaceViewDirection, upDirection);
        return mix(skyColor, fogColor, 1.0 - smoothstep(0.1, 0.25, max(viewDotUp, 0.0)));
    #else
        return fogColor;
    #endif
}

void addStars(vec3 eyeSpaceViewDirection, float sunDotUp, float horizonFactor, bool isFog, inout vec3 skyColor, inout float emissivness) {
    if (!isFog) {
        // only during night in the overworld
        #if defined OVERWORLD
            if (sunDotUp < 0.15)
        #endif
        {
            // inverse vector if in south hemisphere (avoid stretching)
            if (eyeSpaceViewDirection.y < 0.0) eyeSpaceViewDirection *= -1.0;

            const float sacleFactor = 350.0;
            const float threshold = 0.995;
            eyeSpaceViewDirection.y += 0.75; // offset to avoid pole streching

            vec3 polarEyeSpacePosition = cartesianToPolar(eyeSpaceViewDirection);
            vec2 seed = vec2(floor(polarEyeSpacePosition.x * sacleFactor), floor(polarEyeSpacePosition.y * sacleFactor));

            // add star
            if (interleavedGradient(seed) > threshold) {
                float noise = interleavedGradient(seed+1.5);
                float intensity = noise * noise;
                // only during night in the overworld
                #if defined OVERWORLD
                    intensity = mix(intensity, 0.0, smoothstep(-0.15, 0.15, sunDotUp));
                #endif
                intensity = mix(intensity, 0.0, max(horizonFactor * 1.5, 0.0));
                intensity = min(max(intensity, 0.0), (1 - rainStrength));
                skyColor = mix(skyColor, vec3(1.0), intensity);
                emissivness = intensity;
            }
        }
    }
}

// custom
vec3 getCustomSkyColor(vec3 eyeSpacePosition, bool isFog, out float emissivness) {
    emissivness = 0.0;
    vec3 skyColor = vec3(0.0);

    // directions 
    vec3 eyeSpaceSunDirection = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 eyeSpaceViewDirection = normalize(eyeSpacePosition);

    // angles
    float sunDotUp = dot(eyeSpaceSunDirection, upDirection);
    float viewDotUp = dot(eyeSpaceViewDirection, upDirection);
    float viewDotSun = dot(eyeSpaceViewDirection, eyeSpaceSunDirection);

    // sky light color
    vec3 skyLightColor = getSkyLightColor();

    // OVERWORLD
    #if defined OVERWORLD

        // -- base color -- //
        // day gradient
        vec3 dayColor = mix(dayDownColor, dayMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
        dayColor = mix(dayColor, dayTopColor, smoothstep(0.25, 1.0, viewDotUp));
        // night gradient
        vec3 nightColor = mix(nightDownColor, nightMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
        nightColor = mix(nightColor, nightTopColor, smoothstep(0.25, 1.0, viewDotUp));
        nightColor *= 0.5;
        // blend between night, day
        skyColor = mix(nightColor, dayColor, smoothstep(-0.15, 0.25, sunDotUp));

        // -- sunset -- //
        // sunset gradient
        vec3 sunsetColor = mix(sunsetDownColor, sunsetMiddleColor, smoothstep(-0.25, 0.3, viewDotUp));
        sunsetColor = mix(sunsetColor, sunsetTopColor, smoothstep(0.0, 0.5, viewDotUp));
        sunsetColor = mix(sunsetColor, sunsetHighColor, smoothstep(0.3, 1.0, viewDotUp));
        // blend
        float sunsetFactor = min(smoothstep(-0.1, 0.0, sunDotUp), 1.0 - smoothstep(0.0, 0.45, sunDotUp));
        skyColor = mix(skyColor, sunsetColor, sunsetFactor);
        // add reddish color near the sun
        float redSunsetFactor = 1.0 - smoothstep(0.0, 0.2, abs(viewDotUp));
        redSunsetFactor = mix(0.0, redSunsetFactor, max(viewDotSun, 0.0));
        skyColor = mix(skyColor, sunsetNearColor, sunsetFactor * redSunsetFactor * 0.75);

        // -- rain -- //
        // rainy gradient
        vec3 rainyColor = mix(rainyDownColor, rainyMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
        rainyColor = mix(rainyColor, rainyTopColor, smoothstep(0.25, 1.0, viewDotUp));
        // darken rainy sky during night
        rainyColor *= mix(0.075, 1.0, smoothstep(-0.15, 0.25, sunDotUp));
        skyColor = mix(skyColor, rainyColor, rainStrength);
        skyColor = mix(skyColor, 0.25 * skyColor, thunderStrength);

        // -- horizon fog -- //
        vec3 fogColor = 0.75 * saturate(skyColor, 1.5);
        float horizonFactor = 1.0 - smoothstep(-1.0, 0.2, viewDotUp);
        skyColor = mix(skyColor, fogColor, horizonFactor);

        // -- glare -- //
        float glareFactor = 0.0;
        // sun glare
        if (viewDotSun > 0.0) {
            glareFactor = 0.5 * exp(- 5.0 * abs(viewDotSun - 1.0)) * (1.0 - abs(viewDotSun - 1.0));
            glareFactor = clamp(glareFactor, 0.0, 1.0);
            glareFactor *= smoothstep(-0.15, 0.0, sunDotUp); // remove glare if under horizon
            glareFactor *= abs(sunDotUp);
        }
        // moon glare
        else {
            glareFactor = map(getMoonPhase(), 0.0, 1.0, 0.05, 0.15) * exp(- 40.0 * abs(viewDotSun + 1.0));
            glareFactor = clamp(glareFactor, 0.0, 1.0);
            glareFactor *= smoothstep(-0.15, 0.0, - sunDotUp); // remove glare if under horizon
        }
        // attenuate as it rains
        glareFactor = mix(glareFactor, glareFactor * 0.5, rainStrength);
        // apply glare
        skyColor = mix(skyColor, vec3(1.0), glareFactor);

        // -- add stars -- //
        addStars(eyeSpaceViewDirection, sunDotUp, horizonFactor, isFog, skyColor, emissivness);

        // -- underground fog -- //
        vec3 undergroundFogColor = vec3(0.08, 0.09, 0.12) * 2.0;
        float heightBlend = map(cameraPosition.y, 40.0, 60.0, 0.0, 1.0);
        skyColor = mix(undergroundFogColor, skyColor, heightBlend);

    // NETHER
    #elif defined NETHER
        skyColor = saturate(pow(fogColor, vec3(1.0/2.2)), 2.0);

    // END
    #else
        // -- base color -- //
        skyColor = endColor;

        // no horizon
        float horizonFactor = 0.0;

        // -- add stars -- //
        addStars(eyeSpaceViewDirection, sunDotUp, horizonFactor, isFog, skyColor, emissivness);
    #endif

    // -- noise to avoid color bending -- //
    vec3 polarWorldSpaceViewDirection = cartesianToPolar(eyeSpaceViewDirection);
    float dither = 0.015 * interleavedGradient(polarWorldSpaceViewDirection.yz);
    skyColor += dither;

    // apply blindness & darkness
    skyColor = mix(skyColor, linearToSRGB(blindnessColor), max(blindness, darknessFactor));

    return skyColor;
}

vec3 getSkyColor(vec3 eyeSpacePosition, bool isFog, out float emissivness) {
    emissivness = 0.0;

    #if SKY_TYPE == 0
        return getVanillaSkyColor(eyeSpacePosition);
    #else
        return getCustomSkyColor(eyeSpacePosition, isFog, emissivness);
    #endif
}
