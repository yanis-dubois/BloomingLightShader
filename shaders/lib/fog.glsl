vec3 getWaterFogColor() {
    return vec3(0.0, 0.1, 0.3) * 2.0;
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

float getFogAmount(float normalizedLinearDepth, float fogDensity) {
    // return smoothstep(0, 1.0, normalizedLinearDepth);
    // return 1.0 - pow(2.0, - (normalizedLinearDepth * fogDensity)) * (1.0 - normalizedLinearDepth);
    return 1.0 - pow(2.0, - (normalizedLinearDepth * fogDensity) * (normalizedLinearDepth * fogDensity));
}

void foggify(vec3 worldSpacePosition, inout vec3 color, inout float emissivness) {

    // normalized linear depth
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    float normalizedLinearDepth = distanceFromCamera / far;

    // fog color
    vec3 fogColor = getFogColor(isEyeInWater == 1, worldToEye(worldSpacePosition));
    fogColor = SRGBtoLinear(fogColor);

    // vanilla fog (not applied when camera is under water)
    #if FOG_TYPE == 1
        // linear function 
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float vanillaFogBlend = clamp((distanceFromCameraXZ - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
        color = mix(color, fogColor, vanillaFogBlend);
        emissivness = mix(emissivness, 0.0, vanillaFogBlend);

    // custom fog
    #elif FOG_TYPE == 2
        // exponential function
        float fogDensity = getFogDensity(worldSpacePosition.y, isEyeInWater == 1);
        float exponentialFog = getFogAmount(normalizedLinearDepth, fogDensity);
        color = mix(color, fogColor, exponentialFog);
        emissivness = mix(emissivness, 0.0, exponentialFog);

        // linear function (for the end)
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float linearFog = map(distanceFromCameraXZ, far-16.0, far, 0.0, 1.0);
        color = mix(color, fogColor, linearFog);
        emissivness = mix(emissivness, 0.0, linearFog);
    #endif
}
