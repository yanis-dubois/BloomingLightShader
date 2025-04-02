vec3 getWaterFogColor() {
    vec3 HSVfogColor = rgbToHsv(fogColor);
    HSVfogColor.z = clamp(0.66 * HSVfogColor.z, 0.3, 1.0);
    return hsvToRgb(HSVfogColor);
}

// used by volumetric light
vec3 getFogColor(bool isInWater) {
    if (isInWater) return getWaterFogColor();
    return vec3(1.0);
}

vec3 getFogColor(bool isInWater, vec3 eyeSpacePosition) {
    if (isInWater) return getWaterFogColor();
    float _; // useless here
    return getSkyColor(eyeSpacePosition, true, _);
}

const float minimumFogDensity = 0.5; // 0.5
const float maximumFogDensity = 3.0; // 3.0
float getFogDensity(float worldSpaceHeight, bool isInWater) {
    if (isInWater) return maximumFogDensity;

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
    float caveHeightFactor = 1.0 - map(worldSpaceHeight, 2.0, 32.0, 0.0, 1.0);
    density = mix(density, maximumFogDensity, caveHeightFactor);

    return density;
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
    // linear vanilla fog (tweaked when camera is under water)
    float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
    float fogFactor = map(distanceFromCameraXZ, far - 16.0, far, 0.0, 1.0);

    // normalized linear depth
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    float normalizedLinearDepth = distanceFromCamera / far;

    // custom fog
    #if FOG_TYPE == 2
        float fogDensity = getFogDensity(worldSpacePosition.y, isEyeInWater == 1);
        // exponential function
        // float exponentialFog = 1.0 - pow(2.0, - (normalizedLinearDepth * fogDensity)) * (1.0 - normalizedLinearDepth);
        // exponential function x linear
        // float exponentialFog = 1.0 - pow(2.0, - (normalizedLinearDepth * fogDensity) * (normalizedLinearDepth * fogDensity));
        fogDensity = 1.0 - map(fogDensity, 0.5, 3.0, 0.3, 0.8);
        if (isEyeInWater == 1) fogDensity = min(fogDensity, fogEnd/(1.5*far));
        fogFactor = getCustomFogFactor(normalizedLinearDepth, fogDensity);
        // fogFactor = max(fogFactor, exponentialFog);
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
