const vec3 sunDawn_2000K = vec3(1.0, 0.5367385310486179, 0.05452576587829767);
const vec3 blockLow_3000K = vec3(1.0, 0.6949030005552019, 0.4310480202110507);
const vec3 blockMed_4500K = vec3(1.0, 0.8530674700617857, 0.7350351155108239);
const vec3 blockHigh_5500K = vec3(1.0, 0.931345411760339, 0.8715508191543596);
const vec3 sunZenith_6000K = vec3(1.0, 0.9652869470673199, 0.9287833665638421);
const vec3 moonFullMidnight_7500K = vec3(0.9013970605078236, 0.9209247435099642, 1.0);
const vec3 rainy_8000K = vec3(0.8675084288560855, 0.9011340745165255, 1.0);
const vec3 shadow_10000K = vec3(0.7909974347833513, 0.8551792944545848, 1.0);
const vec3 moonDawn_20000K = vec3(0.6694260712462251, 0.7779863207340414, 1.0);

float getLightness(vec3 color) {
    return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

vec3 getSkyColor() {
    
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
    float moonPhaseBlend = moonPhase < 4 ? float(moonPhase) / 4.0 : (4.0 - (float(moonPhase)-4.0)) / 4.0; 
    moonPhaseBlend = cos(moonPhaseBlend * PI) / 2.0 + 0.5; // [0;1] new=0, full=1

    // moon color
    vec3 moonDawnColor = moonDawn_20000K;
    vec3 moonFullMidnightColor = moonFullMidnight_7500K;
    vec3 moonNewMidnightColor = moonDawn_20000K;
    vec3 moonMidnightColor = mix(moonFullMidnightColor, moonNewMidnightColor, moonPhaseBlend);
    vec3 moonLightColor = 0.66 * mix(moonDawnColor, moonMidnightColor, cosThetaToSigmoid(abs(sunDirectionDotUp), 5.0, 5.5, 1.0));

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

vec3 getFogColor(bool isInWater) {
    if (isInWater) return vec3(0.0,0.1,0.3);
    return vec3(0.8);
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

float getFogAmount(float linearDepth, float fogDensity) {
    return clamp(1 - pow(2, -pow((linearDepth * fogDensity), 2)), 0, 0.9);
}
