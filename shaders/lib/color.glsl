
float getLightness(vec3 color) {
    return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

vec3 kelvinToRGB(float kelvin) {
    // Normalize the Kelvin value to fit the range.
    float temperature = kelvin / 100.;

    // Initialize RGB values
    float red, green, blue;

    // Calculate red
    if (temperature <= 66.) {
        red = 1.;
    } else {
        red = temperature - 60.;
        red = 329.698727446 * pow(red, -0.1332047592);
        red = clamp(min(255., red), 0, 255) / 255.;
    }

    // Calculate green
    if (temperature <= 66.) {
        green = temperature;
        green = 99.4708025861 * log(green) - 161.1195681661;
    } else {
        green = temperature - 60.;
        green = 288.1221695283 * pow(green, -0.0755148492);
    }
    green = clamp(min(255., green), 0, 255) / 255.;

    // Calculate blue
    if (temperature >= 66.) {
        blue = 1.;
    } else {
        if (temperature <= 19.) {
            blue = 0.;
        } else {
            blue = temperature - 10.;
            blue = 138.5177312231 * log(blue) - 305.0447927307;
            blue = clamp(min(255., blue), 0, 255) / 255.;
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
    float moonPhaseBlend = moonPhase < 4 ? moonPhase*1.0 / 4.0 : (4.0 - (moonPhase*1.0-4.0)) / 4.0; 
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

    return skyLightColor;
}

vec3 getBlockLightColor() {
    float blockColorTemperature = 4500.0;
    vec3 blockLightColor = kelvinToRGB(blockColorTemperature);
    blockLightColor = SRGBtoLinear(blockLightColor);

    return blockLightColor;
}
