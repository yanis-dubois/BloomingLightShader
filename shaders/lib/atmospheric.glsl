const vec3 sunDawn_2000K = vec3(1.0, 0.5367385310486179, 0.05452576587829767);
const vec3 blockLow_3000K = vec3(1.0, 0.6949030005552019, 0.4310480202110507);
const vec3 blockMed_4500K = vec3(1.0, 0.8530674700617857, 0.7350351155108239);
const vec3 blockHigh_5500K = vec3(1.0, 0.931345411760339, 0.8715508191543596);
const vec3 sunZenith_6000K = vec3(1.0, 0.9652869470673199, 0.9287833665638421);
const vec3 moonFullMidnight_7500K = vec3(0.9013970605078236, 0.9209247435099642, 1.0);
const vec3 rainy_8000K = vec3(0.8675084288560855, 0.9011340745165255, 1.0);
const vec3 shadow_10000K = vec3(0.7909974347833513, 0.8551792944545848, 1.0);
const vec3 moonDawn_20000K = vec3(0.6694260712462251, 0.7779863207340414, 1.0);

const float rayleighCoefficient = 0.0025;
const float mieCoefficient = 0.0005;
const float mieAsymmetry = 0.76;

// -------- LIGHT -------- //
float getLightness(vec3 color) {
    return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

// [0;1] new=0, full=1
float getMoonPhase() {
    float moonPhaseBlend = moonPhase < 4 ? float(moonPhase) / 4.0 : (4.0 - (float(moonPhase)-4.0)) / 4.0; 
    return cos(moonPhaseBlend * PI) / 2.0 + 0.5; 
}

vec3 getSkyLightColor() {
    // no variations
    if (SKY_LIGHT_COLOR == 0)
        return vec3(1);

    // day time
    vec3 upDirection = vec3(0,1,0);
    vec3 sunLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunDirectionDotUp = dot(sunLightDirectionWorldSpace, upDirection);
    
    // sun color
    vec3 sunDawnColor = sunDawn_2000K;
    vec3 sunZenithColor = sunZenith_6000K;
    vec3 sunLightColor = mix(sunDawnColor, sunZenithColor, cosThetaToSigmoid(sunDirectionDotUp, 0.00001, 20.0, 1.0));
    
    // moon phase
    float moonPhaseBlend = getMoonPhase();

    // moon color
    vec3 moonDawnColor = moonDawn_20000K;
    vec3 moonFullMidnightColor = moonFullMidnight_7500K;
    vec3 moonNewMidnightColor = moonDawn_20000K;
    vec3 moonMidnightColor = mix(moonFullMidnightColor, moonNewMidnightColor, moonPhaseBlend);
    vec3 moonLightColor = 0.5 * mix(moonDawnColor, moonMidnightColor, cosThetaToSigmoid(abs(sunDirectionDotUp), 5.0, 5.5, 1.0));

    // sky color 
    vec3 rainySkyColor = 0.9 * rainy_8000K;
    float skyDayNightBlend = sigmoid(sunDirectionDotUp, 1.0, 50.0);
    vec3 skyLightColor = mix(moonLightColor, sunLightColor, skyDayNightBlend);
    skyLightColor = mix(skyLightColor, skyLightColor*rainySkyColor, rainStrength); // reduce contribution if it rain
    
    // sky color if under water
    if (isEyeInWater==1) 
        skyLightColor = vec3(getLightness(skyLightColor));

    skyLightColor = SRGBtoLinear(skyLightColor);
    return skyLightColor;
}

vec3 getBlockLightColor(float blockLightIntensity, float emissivness) {
    #if BLOCK_LIGHT_COLOR == 0
        return SRGBtoLinear(blockMed_4500K);
    #else
        vec3 blockLightColorBright = blockHigh_5500K;
        vec3 blockLightColorLow = blockLow_3000K;
        blockLightColorLow = vec3(1.0, 0.7550343411105364, 0.5522611122310889); // 3500

        blockLightColorBright = SRGBtoLinear(blockLightColorBright);
        blockLightColorLow = SRGBtoLinear(blockLightColorLow);

        blockLightColorBright *= max(max((1-emissivness) * 1.5, 1) * exp(- 10 * (blockLightIntensity-1)*(blockLightIntensity-1)), emissivness);
        blockLightColorLow *= blockLightIntensity;

        return blockLightColorBright + blockLightColorLow;
    #endif
}

// -------- SKY -------- //
// vanilla 
vec3 getVanillaSkyColor(vec3 worldSpacePosition) {
    vec3 worldSpaceViewDirection = normalize(worldSpacePosition);
	float viewDotUp = dot(worldSpaceViewDirection, vec3(0,1,0));
	return mix(skyColor, fogColor, 1 - smoothstep(0.1, 0.25, max(viewDotUp, 0.0)));
}

// custom
vec3 getCustomSkyColor(vec3 eyeSpacePosition) {

    // directions 
    vec3 upDirection = vec3(0,1,0);
    vec3 eyeSpaceSunDirection = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 eyeSpaceViewDirection = normalize(eyeSpacePosition);

    // angles
    float sunDotUp = dot(eyeSpaceSunDirection, upDirection);
    float viewDotUp = dot(eyeSpaceViewDirection, upDirection);
    float viewDotSun = dot(eyeSpaceViewDirection, eyeSpaceSunDirection);

    // sky light color
    vec3 skylightColor = getSkyLightColor();

    // fog color
    vec3 fogColor = mix(vec3(1), skylightColor, 0.75);
    // !!!!!!!!! add blending ??

    // -- base color -- //
    // day colors
    vec3 dayDownColor = vec3(0.7, 0.8, 1);
    vec3 dayMiddleColor = vec3(0.48, 0.7, 1);
    vec3 dayTopColor = vec3(0.25, 0.5, 1);
    // day gradient
    vec3 dayColor = mix(dayDownColor, dayMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
    dayColor = mix(dayColor, dayTopColor, smoothstep(0.25, 1, viewDotUp));
    // night colors
    vec3 nightDownColor = vec3(0.15, 0.13, 0.3);
    vec3 nightMiddleColor = vec3(0.07, 0.06, 0.15); 
    vec3 nightTopColor = vec3(0.005, 0.005, 0.05); 
    // night gradient
    vec3 nightColor = mix(nightDownColor, nightMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
    nightColor = mix(nightColor, nightTopColor, smoothstep(0.25, 1, viewDotUp));
    nightColor *= 0.5;
    // rainy colors
    vec3 rainyDownColor = vec3(0.55, 0.6, 0.7);
    vec3 rainyMiddleColor = vec3(0.35, 0.4, 0.45); 
    vec3 rainyTopColor = vec3(0.2, 0.25, 0.3); 
    // rainy gradient
    vec3 rainyColor = mix(rainyDownColor, rainyMiddleColor, smoothstep(-0.25, 0.5, viewDotUp));
    rainyColor = mix(rainyColor, rainyTopColor, smoothstep(0.25, 1, viewDotUp));
    rainyColor *= mix(0.3, 1, smoothstep(-0.15, 0.25, sunDotUp));
    // blend between night & day
    vec3 skyColor = mix(nightColor, dayColor, smoothstep(-0.15, 0.25, sunDotUp));
    skyColor = mix(skyColor, rainyColor, rainStrength);

    // -- glare -- //
    vec3 glareColor = mix(vec3(1), skyColor, 0.33);
    float glareFactor = 0;
    if (viewDotSun > 0) glareFactor = 0.5 * exp(- 5 * abs(viewDotSun - 1)) * (1 - abs(viewDotSun - 1)); // sun glare
    else glareFactor = map(getMoonPhase(), 0, 1, 0.05, 0.15) * exp(- 40 * abs(viewDotSun + 1)); // moon glare
    glareFactor = mix(glareFactor, glareFactor * 0.5, rainStrength);
    skyColor = mix(skyColor, skyColor*0.6 + glareColor, glareFactor);

    // -- horizon fog -- //
    float horizonOffset = - 0.5;
    float horizonFactor = clamp(- (eyeSpaceViewDirection.y + horizonOffset), 0, 1);
    horizonFactor = smoothstep(0, 1, horizonFactor);
    horizonFactor = smoothstep(0.3, -0.25, viewDotUp);
    skyColor = mix(skyColor, fogColor, horizonFactor);

    // -- noise to avoid color bending -- //
    vec3 polarWorldSpaceViewDirection = cartesianToPolar(eyeSpaceViewDirection);
    float noise = 0.01 * pseudoRandom(polarWorldSpaceViewDirection.yz);
    skyColor += noise;

    // -- stars -- //
    float SunDotUp = dot(normalize(mat3(gbufferModelViewInverse) * sunPosition), vec3(0,1,0));
    if (SunDotUp < 0.15) {
        float sacleFactor = 350;
        float threshold = 0.995;
        eyeSpacePosition.y += 0.75; // offset to avoid pole streching
        vec3 polarEyeSpacePosition = cartesianToPolar(eyeSpacePosition);
        vec2 seed = vec2(floor(polarEyeSpacePosition.x * sacleFactor), floor(polarEyeSpacePosition.y * sacleFactor));
        // vec3 seed = vec3(floor(eyeSpacePosition.x * sacleFactor), floor(eyeSpacePosition.y * sacleFactor), floor(eyeSpacePosition.z * sacleFactor));

        // if there is a star at this coord
        if (pseudoRandom(seed) > threshold) {
            float noise_ = pseudoRandom(seed+1);
            float intensity = noise_*noise_;
            intensity = mix(intensity, 0, smoothstep(-0.15, 0.15, SunDotUp));
            intensity = mix(intensity, 0, max(horizonFactor * 1.5, 0));
            skyColor = mix(skyColor, vec3(1), max(intensity, 0));
            // emissivness = intensity * 0.5;
        }
    }

    return skyColor;
}

vec3 getSkyColor(vec3 worldSpacePosition) {
    #if SKY_TYPE == 0
        return getVanillaSkyColor(worldSpacePosition);
    #else
        return getCustomSkyColor(worldSpacePosition);
    #endif
}

// -------- FOG -------- //
vec3 getFogColor(bool isInWater) {
    if (isInWater) return vec3(0.0,0.1,0.3);
    return vec3(0.9);
}

vec3 getFogColor(bool isInWater, vec3 worldSpacePosition) {
    if (isInWater) return vec3(0.0,0.1,0.3);
    return getSkyColor(worldSpacePosition);
}

const float minimumFogDensity = 0.5;
const float maximumFogDensity = 3;
float getFogDensity(float worldSpaceHeight, bool isInWater) {
    if (isInWater) return maximumFogDensity * 1.5;

    float minFogDensity = sunAngle > 0.5 ? minimumFogDensity*2 : minimumFogDensity;
    float maxFogDensity = maximumFogDensity;

    vec3 upDirection = vec3(0,1,0);
    vec3 lightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotUp = dot(lightDirectionWorldSpace, upDirection);
    if (sunAngle < 0.5) lightDirectionDotUp = pow(lightDirectionDotUp, 0.33);

    float density = mix(minFogDensity, maxFogDensity, 1-lightDirectionDotUp);
    density = mix(density, maxFogDensity, rainStrength);

    // reduce density as height increase
    float height = map(worldSpaceHeight, 62, 102, 0, 1);
    density *= exp(-height);

    return density;
}

float getFogAmount(float normalizedLinearDepth, float fogDensity) {
    return 1 - pow(2, -pow((normalizedLinearDepth * fogDensity), 2));
}

vec3 foggify(vec3 color, vec3 worldSpacePosition, float normalizedLinearDepth) {

    // fog color
    vec3 fogColor = getFogColor(isEyeInWater==1, worldToEye(worldSpacePosition));
    fogColor = SRGBtoLinear(fogColor);

    // vanilla fog (not applied when camera is under water)
    if (FOG_TYPE == 1 || (FOG_TYPE == 2 && isEyeInWater==0)) {
        // linear function 
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float vanillaFogBlend = clamp((distanceFromCameraXZ - fogStart) / (fogEnd - fogStart), 0, 1);
        color = mix(color, fogColor, vanillaFogBlend);
    }
    // custom fog
    if (FOG_TYPE == 2) {
        // density decrease with height
        float fogDensity = getFogDensity(worldSpacePosition.y, isEyeInWater==1);
        // exponential function
        float fogAmount = getFogAmount(normalizedLinearDepth, fogDensity);
        color = mix(color, fogColor, fogAmount);
    }

    return color;
}
