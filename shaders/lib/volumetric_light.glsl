void volumetricLighting(vec2 uv, float depth, float ambientSkyLightIntensity,
                        inout vec3 color) {

    vec3 skyLightColor = getSkyLightColor();
    bool isInWater = isEyeInWater==1;

    // parameters
    float absorptionCoefficient = 0.0;
    float scatteringCoefficient = 0.0;
    float sunIntensity = mix(VOLUMETRIC_LIGHT_INTENSITY, VOLUMETRIC_LIGHT_INTENSITY*0.5, rainStrength);

    // distances
    vec3 fragmentWorldSpacePosition = viewToWorld(screenToView(uv, depth));
    float fragmentDistance = distance(cameraPosition, fragmentWorldSpacePosition);
    float clampedMaxDistance = clamp(fragmentDistance, 0.001, far);
    // direction
    vec3 worldSpaceViewDirection = normalize(fragmentWorldSpacePosition - cameraPosition);

    // decrease volumetric light effect as light source and view vector are align
    // -> avoid player shadow monster 
    vec3 worldSpaceLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float LdotV = dot(worldSpaceViewDirection, worldSpaceLightDirection);
    float attenuationFactor = map(pow(LdotV * 0.5 + 0.5, 0.5), 0.0, 1.0, 0.25, 1.0);

    // decrease volumetric light that is added on sky
    // which is even truer the further up you look
    float VdotU = dot(worldSpaceViewDirection, upDirection);
    float invVdotU = 1.0 - max(VdotU, 0.0);
    attenuationFactor *= invVdotU * invVdotU * invVdotU;

    // init loop
    vec3 accumulatedLight = vec3(0.0);
    vec3 rayWorldSpacePosition = cameraPosition;
    #ifdef END
        rayWorldSpacePosition += worldSpaceViewDirection * min(0.5*far, 128.0);

        if (clampedMaxDistance < min(0.5*far, 128.0)) {
            return;
        }

        float travelLength = clamp(distance(rayWorldSpacePosition, fragmentWorldSpacePosition), 0.001, min(0.5*far, 192.0));

        float stepsCount = clamp(travelLength * VOLUMETRIC_LIGHT_RESOLUTION, VOLUMETRIC_LIGHT_MIN_SAMPLE, VOLUMETRIC_LIGHT_MAX_SAMPLE); // nb steps
        float stepSize = travelLength / stepsCount; // clamp max distance and divide by step count
    #else
        float stepsCount = clamp(clampedMaxDistance * VOLUMETRIC_LIGHT_RESOLUTION, VOLUMETRIC_LIGHT_MIN_SAMPLE, VOLUMETRIC_LIGHT_MAX_SAMPLE); // nb steps
        float stepSize = clampedMaxDistance / stepsCount; // clamp max distance and divide by step count
    #endif
    float dither = dithering(uv, VOLUMETRIC_LIGHT_DITHERING_TYPE);
    float randomizedStepSize = stepSize * dither;
    rayWorldSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    float rayDistance = 0.0;

    //
    vec3 shadowColor = vec3(0.0);
    float maxScattering = 0.0;
    bool hasColoredShadow = false;
    float coloredShadowCpt = 0.0;

    // loop
    for (int i=0; i<stepsCount; ++i) {
        rayDistance = distance(cameraPosition, rayWorldSpacePosition);
        float normalizedRayDistance = min(rayDistance / shadowDistance, 1.0);

        // ray goes beneath block
        if (rayDistance > clampedMaxDistance) {
            break;
        }

        // density
        scatteringCoefficient = 0.012 * getVolumetricFogDensity(rayWorldSpacePosition.y, normalizedRayDistance);
        maxScattering = max(maxScattering, scatteringCoefficient);

        // get shadow
        #ifdef OVERWORLD
            vec4 shadowClipPos = playerToShadowClip(worldToPlayer(rayWorldSpacePosition));
            vec4 shadow = getShadow(shadowClipPos, true);
            vec3 shadowedLight = mix(shadow.rgb, vec3(0.0), shadow.a);

            if (0.0 < shadow.a && shadow.a < 1.0) {
                hasColoredShadow = true;
                shadowColor += shadow.rgb;
                coloredShadowCpt++;
            }

        #elif defined NETHER
            float shadowTransparency = getNetherVolumetricFog(frameTimeCounter, rayWorldSpacePosition);
            vec3 shadowedLight = mix(vec3(0.0), vec3(1.0), shadowTransparency);

        #else
            vec3 color = vec3(0.0);
            float shadowTransparency = getEndVolumetricFog(frameTimeCounter, rayWorldSpacePosition, color);
            vec3 shadowedLight = mix(vec3(0.0), color, shadowTransparency);
        #endif

        // compute inscattered light
        float scatteringAbsorption = exp(-absorptionCoefficient * normalizedRayDistance) * (1.0 - normalizedRayDistance);
        scatteringAbsorption = 1.0;
        vec3 inscatteredLight = shadowedLight * scatteringAbsorption * stepSize;
        #ifndef OVERWORLD
            inscatteredLight *= scatteringCoefficient;
        #endif

        // add light contribution
        accumulatedLight += inscatteredLight;

        // go a step further
        rayWorldSpacePosition += worldSpaceViewDirection * stepSize;
    }

    #if defined OVERWORLD
        // scattering tricks
        accumulatedLight *= maxScattering;
        // apply attenuation
        accumulatedLight *= attenuationFactor;
        // day-night & weather transition
        accumulatedLight *= mix(1.0, 0.5, rainStrength) * getDayNightBlend() * sunIntensity;
        // sky light
        accumulatedLight *= mix(skyLightColor, saturate(skyLightColor, 0.25), rainStrength);
        // fog color
        accumulatedLight *= SRGBtoLinear(getVolumetricFogColor());

        // add contrast if there is no rain
        float contrast = sunAngle < 0.5 ? 1.05 : 1.015;
        vec3 contrastedLight = clamp((accumulatedLight - 0.5) * contrast + 0.5, 0.0, 1.0);
        accumulatedLight = mix(contrastedLight, accumulatedLight, rainStrength);

        if (hasColoredShadow && isEyeInWater==0) {
            accumulatedLight *= shadowColor/coloredShadowCpt;
        }

    #elif defined NETHER
        // fog color
        accumulatedLight *= SRGBtoLinear(getVolumetricFogColor());
    #endif

    // write values
    color = mix(color + accumulatedLight, color, max(blindness, darknessFactor));
}
