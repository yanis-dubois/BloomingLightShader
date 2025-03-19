// -- light color -- //
const vec3 light2000K = vec3(1.0, 0.5367385310486179, 0.05452576587829767); // dawn sun light
const vec3 light3500K = vec3(1.0, 0.7550343411105364, 0.5522611122310889); // block low intensity light
const vec3 light4500K = vec3(1.0, 0.8530674700617857, 0.7350351155108239); // block med intensity light
const vec3 light5500K = vec3(1.0, 0.931345411760339, 0.8715508191543596); // block high intensity light
const vec3 light6000K = vec3(1.0, 0.9652869470673199, 0.9287833665638421); // zenith sun light
const vec3 light7500K = vec3(0.9013970605078236, 0.9209247435099642, 1.0); // full moon light
const vec3 light8000K = vec3(0.8675084288560855, 0.9011340745165255, 1.0); // rainy sky light
const vec3 light10000K = vec3(0.7909974347833513, 0.8551792944545848, 1.0); // shadow light
const vec3 light20000K = vec3(0.6694260712462251, 0.7779863207340414, 1.0); // dawn moon light

vec3 getSkyLightColor() {
    // no variations
    #if SKY_LIGHT_COLOR == 0
        return vec3(1.0);
    #else
        // day time
        vec3 eyeSpaceSunDirection = normalize(mat3(gbufferModelViewInverse) * sunPosition);
        vec3 eyeSpaceMoonDirection = normalize(mat3(gbufferModelViewInverse) * moonPosition);
        float sunDotUp = dot(eyeSpaceSunDirection, upDirection); // highly redundant !!!!!!!!!!!!!!!!!!!!!!!!!!
        float moonDotUp = dot(eyeSpaceMoonDirection, upDirection);

        // sun light
        vec3 sunLightColor = mix(light2000K, light4500K, smoothstep(0.05, 0.3, sunDotUp));
        sunLightColor = mix(sunLightColor, light6000K, smoothstep(0.25, 0.7, sunDotUp));

        // moon light
        float moonPhaseBlend = getMoonPhase();
        vec3 moonMidnightColor = mix(light7500K, light20000K, moonPhaseBlend);
        vec3 moonLightColor = 0.5 * mix(light20000K, moonMidnightColor, smoothstep(0.8, 1, moonDotUp));

        // sky light
        vec3 skyLightColor = mix(moonLightColor, sunLightColor, smoothstep(-0.1, 0.1, sunDotUp));
        // rainy sky light
        skyLightColor = mix(skyLightColor, skyLightColor * 0.9 * light8000K, rainStrength);

        // under water sky light
        if (isEyeInWater==1) 
            skyLightColor = vec3(getLightness(skyLightColor));

        skyLightColor = SRGBtoLinear(skyLightColor);
        return skyLightColor;
    #endif
}

vec3 getShadowLightColor() {

    // day time
    vec3 eyeSpaceSunDirection = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunDotUp = dot(eyeSpaceSunDirection, upDirection);

    // day
    vec3 dayShadow = mix(light6000K, light7500K, smoothstep(0.05, 0.3, sunDotUp));
    dayShadow = mix(dayShadow, light10000K, smoothstep(0.25, 0.7, sunDotUp));

    // night shadow
    vec3 nightShadow = light20000K;

    // blend
    vec3 shadowColor = mix(nightShadow, dayShadow, smoothstep(-0.1, 0.1, sunDotUp));
    // rainy shadow
    shadowColor = mix(shadowColor, shadowColor * 0.9 * light8000K, rainStrength);

    // under water shadow
    if (isEyeInWater==1) 
        shadowColor = vec3(getLightness(shadowColor));

    shadowColor = SRGBtoLinear(shadowColor);
    return shadowColor;
}

vec3 getBlockLightColor(float blockLightIntensity, float emissivness) {
    #if BLOCK_LIGHT_COLOR == 0
        return SRGBtoLinear(light4500K);
    #else
        vec3 blockLightColorBright = light5500K;
        vec3 blockLightColorLow = light3500K;

        blockLightColorBright = SRGBtoLinear(blockLightColorBright);
        blockLightColorLow = SRGBtoLinear(blockLightColorLow);

        blockLightColorBright *= max(max((1-emissivness) * 1.5, 1) * exp(- 10 * (blockLightIntensity-1)*(blockLightIntensity-1)), emissivness);
        blockLightColorLow *= blockLightIntensity;

        return blockLightColorBright + blockLightColorLow;
    #endif
}
