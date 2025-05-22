vec3 getWaterFogColor() {
    vec3 HSVfogColor = rgbToHsv(fogColor);
    HSVfogColor.z = clamp(0.66 * HSVfogColor.z, 0.3, 1.0);
    return hsvToRgb(HSVfogColor);
}

vec3 getLavaFogColor() {
    return fogColor;
}

// used by volumetric light
vec3 getFogColor(bool isInWater) {
    if (isInWater) return getWaterFogColor();
    return vec3(1.0);
}

vec3 getFogColor(bool isInWater, vec3 eyeSpacePosition) {
    if (isEyeInWater > 1) return getLavaFogColor();
    if (isInWater) return getWaterFogColor();
    float _; // useless here
    return getSkyColor(eyeSpacePosition, true, _);
}

vec3 getVolumetricFogColor() {
    #ifdef OVERWORLD
        if (isEyeInWater > 1) return getLavaFogColor();
        if (isEyeInWater == 1) return getWaterFogColor();
        return vec3(1.0);
    #else
        vec3 volumetricFogColor = rgbToHsv(clamp(5.0 * fogColor, 0.0, 1.0));
        volumetricFogColor.y -= 0.3; // saturation
        volumetricFogColor.z = 1.0; // value
        volumetricFogColor = hsvToRgb(volumetricFogColor);
        return volumetricFogColor;
    #endif
}

#if defined OVERWORLD
    const float seaLevel = 62.0;
#elif defined NETHER
    const float seaLevel = 30.0;
#else
    const float seaLevel = 0.0; // ???
#endif

float getVolumetricFogDensity(float worldSpaceHeight, float normalizedDistance) {
    if (isEyeInWater >= 1) return 10.0;

    #ifdef OVERWORLD
        float minFogDensity = sunAngle < 0.5 ? 0.01 : 0.27;
        float maxFogDensity = sunAngle < 0.5 ? 0.75 : 0.33;

        // higher density during morning / night / rain
        vec3 lightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        float lightDirectionDotUp = dot(lightDirectionWorldSpace, upDirection);
        if (sunAngle < 0.5) lightDirectionDotUp = pow(lightDirectionDotUp, 0.33);
        float density = mix(minFogDensity, maxFogDensity, 1.0 - lightDirectionDotUp);
        density = mix(density, maxFogDensity, rainStrength);
    #else
        float density = 0.33;
    #endif

    // increase density as the fragment is far away
    float distanceDensityIncrease = pow(2.2, - (normalizedDistance * 3.3) * (normalizedDistance * 3.3)) * (1.0 - normalizedDistance);
    density = mix(density, density * 2.0, distanceDensityIncrease);

    // reduce density from sea level as altitude increase
    #ifdef OVERWORLD
        float heightDensityDecreaseFactor = 0.25;
        float heightFactor = map(worldSpaceHeight, seaLevel, seaLevel+40.0, 0.0, 1.0);
    #else
        float heightDensityDecreaseFactor = 0.05;
        float heightFactor = map(worldSpaceHeight, seaLevel, seaLevel+60.0, 0.0, 1.0);
    #endif
    float heightDensityDecrease = 1.0 - pow(2.2, - (heightFactor * 1.0) * (heightFactor * 1.0)) * (1.0 - heightFactor);
    density = mix(density, heightDensityDecreaseFactor * density, heightDensityDecrease);

    return density;
}

float getFogDensity(float worldSpaceHeight, float normalizedDistance) {
    if (isEyeInWater >= 1) return 1.0;

    #ifdef NETHER
        return 0.25;
    #else
        // higher density in overworld caves
        float caveHeightFactor = 1.0 - map(worldSpaceHeight, 0.0, seaLevel, 0.0, 1.0);
        return mix(0.0, 0.66, caveHeightFactor);
    #endif
}

// density [0.1;0.9]
float getCustomFogFactor(float t, float density) {
    // define bezier curve points
    vec2 P[4] = t < density 
        ? vec2[4](
            vec2(0.0, 0.0),
            vec2(density * 0.5, 0.0),
            max(vec2(density - 0.2 * abs(density - 0.5), 1.0 - density - 0.1), 0.0),
            vec2(density, 1.0 - density)
        )
        : vec2[4](
            vec2(density, 1.0 - density),
            min(vec2(density + 0.2 * abs(density - 0.5), 1.0 - density + 0.1), 1.0),
            vec2((1.0 + density) * 0.5, 1.0),
            vec2(1.0, 1.0)
        );
    
    t = t < density ? map(t, 0.0, density, 0.0, 1.0) : map(t, density, 1.0, 0.0, 1.0);

    // interpolate cubic bezier curve
    vec2 T = (1-t)*(1-t)*(1-t)*P[0] + 3*t*(1-t)*(1-t)*P[1] + 3*t*t*(1-t)*P[2] + t*t*t*P[3];
    return T.y;
}

float getFogFactor(vec3 worldSpacePosition) {

    #ifdef DISTANT_HORIZONS
        float renderDistance = dhRenderDistance;
    #else
        float renderDistance = far;
    #endif

    // in lava
    if (isEyeInWater == 2) {
        renderDistance = 16.0;
    }
    else if (isEyeInWater == 3) {
        renderDistance = 8.0;
    }

    // no fog
    #if FOG_TYPE == 0
        float fogFactor = 0.0;

    // linear fog
    #elif FOG_TYPE == 1
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float fogFactor = map(distanceFromCameraXZ, max(renderDistance - 16.0, 0.0), renderDistance, 0.0, 1.0);
        #ifdef DISTANT_HORIZONS
            if (isEyeInWater == 0) {
                fogFactor = map(distanceFromCameraXZ, far, renderDistance, 0.0, 1.0);
            }
        #endif

    // custom fog
    #else
        // normalized linear depth
        float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
        float normalizedLinearDepth = distanceFromCamera / renderDistance;

        float fogDensity = getFogDensity(worldSpacePosition.y, normalizedLinearDepth);
        fogDensity = 1.0 - map(fogDensity, 0.0, 1.0, 0.2, 0.8);
        float fogFactor = getCustomFogFactor(normalizedLinearDepth, fogDensity);
    #endif

    return clamp(fogFactor, 0.0, 1.0);
}

void foggify(vec3 worldSpacePosition, vec3 fogColor, inout vec3 color, inout float emissivness) {
    float fogFactor = getFogFactor(worldSpacePosition);
    color = mix(color, fogColor, fogFactor);
    emissivness = mix(emissivness, 0.0, fogFactor);
}

void foggify(vec3 worldSpacePosition, vec3 fogColor, inout vec3 color) {
    float fogFactor = getFogFactor(worldSpacePosition);
    color = mix(color, fogColor, fogFactor);
}

void foggify(vec3 worldSpacePosition, inout vec3 color, inout float emissivness) {
    // fog color
    vec3 fogColor = getFogColor(isEyeInWater == 1, worldToEye(worldSpacePosition));
    fogColor = SRGBtoLinear(fogColor);

    foggify(worldSpacePosition, fogColor, color, emissivness);
}

void foggify(vec3 worldSpacePosition, inout vec3 color) {
    // unused emissivness
    float _;
    foggify(worldSpacePosition, color, _);
}

float getBlindnessFactor(vec3 worldSpacePosition, float blindnessDistance) {

    // no fog
    #if FOG_TYPE == 0
        float fogFactor = 0.0;

    // linear vanilla fog (tweaked when camera is under water)
    #elif FOG_TYPE == 1
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float fogFactor = map(distanceFromCameraXZ, 0.0, blindnessDistance, 0.0, 1.0);

    // custom fog
    #else
        // normalized linear depth
        float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
        float normalizedLinearDepth = clamp(distanceFromCamera / blindnessDistance, 0.0, 1.0);

        float fogDensity = 0.5;
        float fogFactor = getCustomFogFactor(normalizedLinearDepth, fogDensity);
    #endif

    return clamp(fogFactor, 0.0, 1.0);
}

void doBlindness(vec3 worldSpacePosition, inout vec3 color, inout float emissivness) {
    // blindness
    float blindnessFogFactor = getBlindnessFactor(worldSpacePosition, blindnessRange);
    color = mix(color, blindnessColor, blindnessFogFactor * blindness);
    emissivness = mix(emissivness, 0.0, blindnessFogFactor * blindness);

    // darkness
    float darknessFogFactor = getBlindnessFactor(worldSpacePosition, darknessRange);
    color = mix(color, blindnessColor, darknessFogFactor * darknessFactor);
    emissivness = mix(emissivness, 0.0, darknessFogFactor * darknessFactor);
}
