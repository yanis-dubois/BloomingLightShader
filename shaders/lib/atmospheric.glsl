// --------------------------------------------- //
// ------------------- CONST ------------------- //
// --------------------------------------------- //

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
// -- sky box color -- //
// day colors
const vec3 dayDownColor = vec3(0.7, 0.8, 1.0);
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
// sunset color
const vec3 sunsetNearColor = vec3(1.0, 0.35, 0.1);
const vec3 sunsetDownColor = vec3(1.0, 0.5, 0.2);
const vec3 sunsetMiddleColor = vec3(0.8, 0.4, 0.6);
const vec3 sunsetTopColor = vec3(0.28, 0.32, 0.55);
const vec3 sunsetHighColor = vec3(0.15, 0.2, 0.5);
// glare
const vec3 glareColor = vec3(0.75);

// --------------------------------------------- //
// ------------------- LIGHT ------------------- //
// --------------------------------------------- //

// [0;1] new=0, full=1
float getMoonPhase() {
    float moonPhaseBlend = moonPhase < 4 ? float(moonPhase) / 4.0 : (4.0 - (float(moonPhase)-4.0)) / 4.0; 
    return cos(moonPhaseBlend * PI) / 2.0 + 0.5; 
}

vec3 getSkyLightColor() {
    // no variations
    if (SKY_LIGHT_COLOR == 0)
        return vec3(1.0);

    // day time
    vec3 eyeSpaceSunDirection = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 eyeSpaceMoonDirection = normalize(mat3(gbufferModelViewInverse) * moonPosition);
    float sunDotUp = dot(eyeSpaceSunDirection, upDirection);
    float moonDotUp = dot(eyeSpaceMoonDirection, upDirection);

    // sun light
    vec3 sunLightColor = mix(light2000K, light4500K, smoothstep(0.05, 0.2, sunDotUp));
    sunLightColor = mix(sunLightColor, light6000K, smoothstep(0.1, 0.7, sunDotUp));

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

// --------------------------------------------- //
// ------------------ SKY BOX ------------------ //
// --------------------------------------------- //

// vanilla 
vec3 getVanillaSkyColor(vec3 eyeSpacePosition) {
    vec3 eyeSpaceViewDirection = normalize(eyeSpacePosition);
	float viewDotUp = dot(eyeSpaceViewDirection, upDirection);
	return mix(skyColor, fogColor, 1.0 - smoothstep(0.1, 0.25, max(viewDotUp, 0.0)));
}

// custom
vec3 getCustomSkyColor(vec3 eyeSpacePosition) {

    // directions 
    vec3 eyeSpaceSunDirection = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 eyeSpaceViewDirection = normalize(eyeSpacePosition);

    // angles
    float sunDotUp = dot(eyeSpaceSunDirection, upDirection);
    float viewDotUp = dot(eyeSpaceViewDirection, upDirection);
    float viewDotSun = dot(eyeSpaceViewDirection, eyeSpaceSunDirection);

    // sky light color
    vec3 skylightColor = getSkyLightColor();

    // fog color
    vec3 fogColor = mix(vec3(0.5), skylightColor, 0.75);

    // -- base color -- //
    // day gradient
    vec3 dayColor = mix(dayDownColor, dayMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
    dayColor = mix(dayColor, dayTopColor, smoothstep(0.25, 1.0, viewDotUp));
    // night gradient
    vec3 nightColor = mix(nightDownColor, nightMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
    nightColor = mix(nightColor, nightTopColor, smoothstep(0.25, 1.0, viewDotUp));
    nightColor *= 0.5;
    // rainy gradient
    vec3 rainyColor = mix(rainyDownColor, rainyMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
    rainyColor = mix(rainyColor, rainyTopColor, smoothstep(0.25, 1.0, viewDotUp));
    // darken rainy sky during night
    rainyColor *= mix(0.3, 1.0, smoothstep(-0.15, 0.25, sunDotUp));
    // blend between night, day & rainy sky
    vec3 skyColor = mix(nightColor, dayColor, smoothstep(-0.15, 0.25, sunDotUp));
    skyColor = mix(skyColor, rainyColor, rainStrength);

    // -- sunset -- //
    // day gradient
    vec3 sunsetColor = mix(sunsetDownColor, sunsetMiddleColor, smoothstep(-0.25, 0.3, viewDotUp));
    sunsetColor = mix(sunsetColor, sunsetTopColor, smoothstep(0.0, 0.5, viewDotUp));
    sunsetColor = mix(sunsetColor, sunsetHighColor, smoothstep(0.3, 1.0, viewDotUp));
    // blend
    float sunsetFactor = min(smoothstep(-0.1, 0.0, sunDotUp), 1.0 - smoothstep(0.0, 0.25, sunDotUp));
    skyColor = mix(skyColor, sunsetColor, sunsetFactor);
    // add reddish color near the sun
    float redSunsetFactor = 1.0 - smoothstep(0.0, 0.2, abs(viewDotUp));
    redSunsetFactor = mix(0.0, redSunsetFactor, max(viewDotSun, 0.0));
    skyColor = mix(skyColor, sunsetNearColor, sunsetFactor * redSunsetFactor * 0.75);

    // -- glare -- //
    float glareFactor = 0.0;
    // sun glare
    if (viewDotSun > 0.0) {
        glareFactor = 0.5 * exp(- 5.0 * abs(viewDotSun - 1.0)) * (1.0 - abs(viewDotSun - 1.0));
        glareFactor *= smoothstep(-0.15, 0.0, sunDotUp); // remove glare if under horizon
    }
    // moon glare
    else {
        glareFactor = map(getMoonPhase(), 0.0, 1.0, 0.05, 0.15) * exp(- 40.0 * abs(viewDotSun + 1.0));
        glareFactor *= smoothstep(-0.15, 0.0, - sunDotUp); // remove glare if under horizon
    }
    // attenuate as it rains
    glareFactor = mix(glareFactor, glareFactor * 0.5, rainStrength);
    // apply glare
    skyColor = mix(skyColor, skyColor*0.6 + glareColor, glareFactor);

    // -- horizon fog -- //
    float horizonFactor = 1.0 - smoothstep(-0.25, 0.3, viewDotUp);
    skyColor = mix(skyColor, fogColor, horizonFactor);

    // -- stars -- //
    if (sunDotUp < 0.15) {
        const float sacleFactor = 350.0;
        const float threshold = 0.995;
        eyeSpaceViewDirection.y += 0.75; // offset to avoid pole streching
        vec3 polarEyeSpacePosition = cartesianToPolar(eyeSpaceViewDirection);
        vec2 seed = vec2(floor(polarEyeSpacePosition.x * sacleFactor), floor(polarEyeSpacePosition.y * sacleFactor));

        // add star
        if (pseudoRandom(seed) > threshold) {
            float noise_ = pseudoRandom(seed+1);
            float intensity = noise_*noise_;
            intensity = mix(intensity, 0.0, smoothstep(-0.15, 0.15, sunDotUp));
            intensity = mix(intensity, 0.0, max(horizonFactor * 1.5, 0.0));
            skyColor = mix(skyColor, vec3(1.0), max(intensity, 0.0));
        }
    }

    // -- underground fog -- //
    vec3 undergroundFogColor = vec3(0.08, 0.09, 0.12);
    float heightBlend = map(cameraPosition.y, 40.0, 60.0, 0.0, 1.0);
    skyColor = mix(undergroundFogColor, skyColor, heightBlend);

    // -- noise to avoid color bending -- //
    vec3 polarWorldSpaceViewDirection = cartesianToPolar(eyeSpaceViewDirection);
    float noise = 0.01 * pseudoRandom(polarWorldSpaceViewDirection.yz);
    skyColor += noise;

    return skyColor;
}

vec3 getSkyColor(vec3 eyeSpacePosition) {
    #if SKY_TYPE == 0
        return getVanillaSkyColor(eyeSpacePosition);
    #else
        return getCustomSkyColor(eyeSpacePosition);
    #endif
}

// --------------------------------------------- //
// -------------------- FOG -------------------- //
// --------------------------------------------- //

vec3 getWaterFogColor() {
    return vec3(0.0, 0.1, 0.3);
}

// used by volumetric light
vec3 getFogColor(bool isInWater) {
    if (isInWater) return getWaterFogColor();
    return vec3(0.75);
}

vec3 getFogColor(bool isInWater, vec3 eyeSpacePosition) {
    if (isInWater) return getWaterFogColor();
    return getSkyColor(eyeSpacePosition);
}

const float minimumFogDensity = 0.5;
const float maximumFogDensity = 3.0;
float getFogDensity(float worldSpaceHeight, bool isInWater) {
    if (isInWater) return maximumFogDensity * 1.5;

    float minFogDensity = sunAngle > 0.5 ? 2.0 * minimumFogDensity : minimumFogDensity;
    float maxFogDensity = maximumFogDensity;

    // higher density during morning / night / rain
    vec3 lightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotUp = dot(lightDirectionWorldSpace, upDirection);
    if (sunAngle < 0.5) lightDirectionDotUp = pow(lightDirectionDotUp, 0.33);
    float density = mix(minFogDensity, maxFogDensity, 1.0 - lightDirectionDotUp);
    density = mix(density, maxFogDensity, rainStrength);

    // reduce density as height increase
    float surfaceHeightFactor = map(worldSpaceHeight, 62.0, 102.0, 0.0, 1.0);
    density *= exp(- surfaceHeightFactor);

    // higher density in caves
    float caveHeightFactor = 1.0 - map(worldSpaceHeight, 32.0, 60.0, 0.0, 1.0);
    density = mix(density, maximumFogDensity, caveHeightFactor);

    return density;
}

float getFogAmount(float normalizedLinearDepth, float fogDensity) {
    return 1.0 - pow(2.0, - pow((normalizedLinearDepth * fogDensity), 2.0));
}

vec3 foggify(vec3 color, vec3 worldSpacePosition, float normalizedLinearDepth) {

    // fog color
    vec3 fogColor = getFogColor(isEyeInWater==1, worldToEye(worldSpacePosition));
    fogColor = SRGBtoLinear(fogColor);

    // vanilla fog (not applied when camera is under water)
    if (FOG_TYPE == 1 || (FOG_TYPE == 2 && isEyeInWater == 0)) {
        // linear function 
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float vanillaFogBlend = clamp((distanceFromCameraXZ - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
        color = mix(color, fogColor, vanillaFogBlend);
    }
    // custom fog
    if (FOG_TYPE == 2) {
        // density decrease with height
        float fogDensity = getFogDensity(worldSpacePosition.y, isEyeInWater == 1);
        // exponential function
        float fogAmount = getFogAmount(normalizedLinearDepth, fogDensity);
        color = mix(color, fogColor, fogAmount);
    }

    return color;
}
