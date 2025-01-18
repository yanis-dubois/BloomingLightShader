
float getLightness(vec3 color) {
    return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

vec3 kelvinToRGB(float kelvin) {
    // Normalize the Kelvin value to fit the range.
    float temperature = kelvin / 100.0;

    // Initialize RGB values
    float red, green, blue;

    // Calculate red
    if (temperature <= 66.0) {
        red = 1.0;
    } else {
        red = temperature - 60.0;
        red = 329.698727446 * pow(red, -0.1332047592);
        red = clamp(min(255.0, red), 0.0, 255.0) / 255.0;
    }

    // Calculate green
    if (temperature <= 66.0) {
        green = temperature;
        green = 99.4708025861 * log(green) - 161.1195681661;
    } else {
        green = temperature - 60.0;
        green = 288.1221695283 * pow(green, -0.0755148492);
    }
    green = clamp(min(255.0, green), 0.0, 255.0) / 255.0;

    // Calculate blue
    if (temperature >= 66.0) {
        blue = 1.0;
    } else {
        if (temperature <= 19.0) {
            blue = 0.0;
        } else {
            blue = temperature - 10.0;
            blue = 138.5177312231 * log(blue) - 305.0447927307;
            blue = clamp(min(255.0, blue), 0.0, 255.0) / 255.0;
        }
    }

    return vec3(red, green, blue);
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
    float sunDawnColorTemperature = 2000.0;
    float sunZenithColorTemperature = 6000.0;
    float sunColorTemperature = clamp(cosThetaToSigmoid(sunDirectionDotUp, 0.00001, 20.0, 1.0) * (sunZenithColorTemperature-sunDawnColorTemperature) + sunDawnColorTemperature, 
                                        sunDawnColorTemperature, 
                                        sunZenithColorTemperature); // [2000;7000] depending at sun angle
    vec3 sunLightColor = kelvinToRGB(sunColorTemperature); 
    
    // moon phase
    float moonPhaseBlend = moonPhase < 4 ? float(moonPhase) / 4.0 : (4.0 - (float(moonPhase)-4.0)) / 4.0; 
    moonPhaseBlend = cos(moonPhaseBlend * PI) / 2.0 + 0.5; // [0;1] new=0, full=1

    // moon color
    float moonDawnColorTemperature = 20000.0;
    float moonFullMidnightColorTemperature = 7500.0;
    float moonNewMidnightColorTemperature = 20000.0;
    float moonMidnightColorTemperature = clamp(moonPhaseBlend * (moonFullMidnightColorTemperature-moonNewMidnightColorTemperature) + moonNewMidnightColorTemperature, 
                                        moonFullMidnightColorTemperature, 
                                        moonNewMidnightColorTemperature); // taking moon phase account
    float moonColorTemperature = clamp(cosThetaToSigmoid(abs(sunDirectionDotUp), 5.0, 5.5, 1.0) * (moonMidnightColorTemperature-moonDawnColorTemperature) + moonDawnColorTemperature, 
                                        moonMidnightColorTemperature, 
                                        moonDawnColorTemperature);
    vec3 moonLightColor = 0.5 * kelvinToRGB(moonColorTemperature); 
    
    // sky color 
    vec3 rainySkyColor = 0.9 * kelvinToRGB(8000);
    float skyDayNightBlend = sigmoid(sunDirectionDotUp, 1.0, 50.0);
    vec3 skyLightColor = mix(moonLightColor, sunLightColor, skyDayNightBlend);
    skyLightColor = mix(skyLightColor, skyLightColor*rainySkyColor, rainStrength); // reduce contribution if it rain
    skyLightColor = SRGBtoLinear(skyLightColor);

    // sky color if under water
    if (isEyeInWater==1) 
        skyLightColor = vec3(getLightness(skyLightColor));

    return skyLightColor;
}

vec3 getSkyLightColor_fast() {
    // no variations
    if (SKY_LIGHT_COLOR == 0)
        return vec3(1);

    // day time
    vec3 upDirection = vec3(0,1,0);
    vec3 sunLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunDirectionDotUp = dot(sunLightDirectionWorldSpace, upDirection);
    
    // sun color
    vec3 sunDawnColor = vec3(1.0, 0.5367385310486179, 0.05452576587829767);
    vec3 sunZenithColor = vec3(1.0, 0.9652869470673199, 0.9287833665638421);
    vec3 sunLightColor = mix(sunDawnColor, sunZenithColor, cosThetaToSigmoid(sunDirectionDotUp, 0.00001, 20.0, 1.0));
    
    // moon phase
    float moonPhaseBlend = moonPhase < 4 ? float(moonPhase) / 4.0 : (4.0 - (float(moonPhase)-4.0)) / 4.0; 
    moonPhaseBlend = cos(moonPhaseBlend * PI) / 2.0 + 0.5; // [0;1] new=0, full=1

    // moon color
    vec3 moonDawnColor = vec3(0.6694260712462251, 0.7779863207340414, 1.0);
    vec3 moonFullMidnightColor = vec3(0.9013970605078236, 0.9209247435099642, 1.0);
    vec3 moonNewMidnightColor = vec3(0.6694260712462251, 0.7779863207340414, 1.0);
    vec3 moonMidnightColor = mix(moonFullMidnightColor, moonNewMidnightColor, moonPhaseBlend);
    vec3 moonLightColor = 0.66 * mix(moonDawnColor, moonMidnightColor, cosThetaToSigmoid(abs(sunDirectionDotUp), 5.0, 5.5, 1.0));
    // 0.5

    // sky color 
    vec3 rainySkyColor = 0.9 * vec3(0.8675084288560855, 0.9011340745165255, 1.0);
    float skyDayNightBlend = sigmoid(sunDirectionDotUp, 1.0, 50.0);
    vec3 skyLightColor = mix(moonLightColor, sunLightColor, skyDayNightBlend);
    skyLightColor = mix(skyLightColor, skyLightColor*rainySkyColor, rainStrength); // reduce contribution if it rain
    
    // sky color if under water
    if (isEyeInWater==1) 
        skyLightColor = vec3(getLightness(skyLightColor));

    skyLightColor = SRGBtoLinear(skyLightColor);
    return skyLightColor;
}

vec3 getBlockLightColor() {
    float blockColorTemperature = 4500.0;
    vec3 blockLightColor = kelvinToRGB(blockColorTemperature);
    blockLightColor = SRGBtoLinear(blockLightColor);

    return blockLightColor;
}

vec3 getBlockLightColor_fast() {
    vec3 blockLightColor = vec3(1.0, 0.8530674700617857, 0.7350351155108239);
    blockLightColor = SRGBtoLinear(blockLightColor);

    return blockLightColor;
}

vec3 getFogColor(bool isInWater) {
    if (isInWater) return vec3(0.0,0.1,0.3);
    return vec3(0.5);
}

const float minimumFogDensity = 0.5;
const float maximumFogDensity = 4;
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
    return clamp(1 - pow(2, -pow((linearDepth * fogDensity), 2)), 0, 1);
}
