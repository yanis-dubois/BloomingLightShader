void volumetricLighting(vec2 uv, float depthAll, float depthOpaque, float ambientSkyLightIntensity,
                        inout vec3 color) {

    vec3 skyLightColor = getSkyLightColor();

    // parameters
    float absorptionCoefficient = 3.0;
    float scatteringCoefficient = 0.0;
    float sunIntensity = VOLUMETRIC_LIGHT_INTENSITY;

    // does ray as a medium change in its trajectory ?
    bool asMediumChange = depthAll<depthOpaque;

    // distances
    vec3 opaqueWorldSpacePosition = viewToWorld(screenToView(uv, depthOpaque));
    vec3 transparentWorldSpacePosition = viewToWorld(screenToView(uv, depthAll));
    float opaqueFragmentDistance = distance(cameraPosition, opaqueWorldSpacePosition);
    float transparentFragmentDistance = distance(cameraPosition, transparentWorldSpacePosition);
    float clampedMaxDistance = clamp(opaqueFragmentDistance, 0.001, min(shadowDistance, far));
    // direction
    vec3 worldSpaceViewDirection = normalize(opaqueWorldSpacePosition - cameraPosition);

    // decrease volumetric light effect as light source and view vector are align
    // -> avoid player shadow monster 
    vec3 worldSpaceLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float LdotV = dot(worldSpaceViewDirection, worldSpaceLightDirection);
    float attenuationFactor = smoothstep(-1.0, 1.0, LdotV);
    attenuationFactor = pow(LdotV * 0.5 + 0.5, 0.42);

    // decrease volumetric light that is added on sky
    // which is even truer the further up you look
    float VdotU = dot(worldSpaceViewDirection, upDirection);
    float invVdotU = 1.0 - max(VdotU, 0.0);
    attenuationFactor *= invVdotU * invVdotU;

    // init loop
    vec3 accumulatedLight = vec3(0.0);
    float stepsCount = clamp(clampedMaxDistance * VOLUMETRIC_LIGHT_RESOLUTION, VOLUMETRIC_LIGHT_MIN_SAMPLE, VOLUMETRIC_LIGHT_MAX_SAMPLE); // nb steps
    float stepSize = clampedMaxDistance / stepsCount; // clamp max distance and divide by step count
    float dither = dithering(uv, VOLUMETRIC_LIGHT_DITHERING_TYPE);
    float randomizedStepSize = stepSize * dither;
    vec3 rayWorldSpacePosition = cameraPosition;
    float rayDistance = 0.0;
    rayWorldSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    bool hasShadow = false;
    bool hasColoredShadow = false;

    vec3 shadowColor = vec3(1.0);

    // loop
    for (int i=0; i<stepsCount; ++i) {
        rayDistance = distance(cameraPosition, rayWorldSpacePosition);

        // ray goes beneath block
        if (rayDistance > opaqueFragmentDistance) {
            break;
        }

        // if in camera in water and ray inside it, or camera outside water but ray goes beneath it
        bool isInWater = 
               (!asMediumChange && isEyeInWater==1) 
            || (asMediumChange && isEyeInWater==1 && rayDistance<transparentFragmentDistance) 
            || (asMediumChange && isEyeInWater!=1 && rayDistance>transparentFragmentDistance);

        // density
        scatteringCoefficient = getFogFactor(rayWorldSpacePosition, isInWater) + 0.2;
        // increase it when underwater
        if (isInWater && isEyeInWater==1) {
            scatteringCoefficient *= 10.0;
        }
        // 
        if (sunAngle > 0.5) {
            scatteringCoefficient *= isInWater ? 0.5 : 0.1;
        }

        // get shadow
        vec4 shadowClipPos = playerToShadowClip(worldToPlayer(rayWorldSpacePosition));
        vec4 shadow = getShadow(shadowClipPos, true);
        if (0.0 < shadow.a && shadow.a < 1.0) {
            shadowColor *= shadow.rgb;
            hasColoredShadow = true;
        }
        vec3 shadowedLight = mix(shadow.rgb, vec3(0.0), shadow.a);

        if (shadow.a > 0.0) hasShadow = true;

        // compute inscattered light
        float normalizedRayDistance = min(rayDistance / (shadowDistance-16.0), 1.0);
        float scattering = exp(-absorptionCoefficient * normalizedRayDistance) * (1.0 - normalizedRayDistance);
        vec3 inscatteredLight = shadowedLight * scatteringCoefficient * sunIntensity;
        inscatteredLight *= scattering;
        // integrate over distance
        inscatteredLight *= randomizedStepSize;
        inscatteredLight *= getFogColor(isInWater);

        // add light contribution
        accumulatedLight += inscatteredLight;

        // go a step further
        rayWorldSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    }

    // apply attenuation
    accumulatedLight *= attenuationFactor;
    // day-night & weather transition
    accumulatedLight *= mix(1.0, 0.5, rainStrength) * getDayNightBlend();
    // enhance colored shaft
    if (hasColoredShadow && isEyeInWater==0) {
        accumulatedLight *= mix(shadowColor, vec3(1.0), 0.25);
    }
    // apply light color only on non colored light shaft
    else {
        accumulatedLight *= skyLightColor;
    }
    // attenuate when no shadow hit (avoid washed out rendering)
    accumulatedLight *= hasShadow ? 1.0 : 0.25;

    // write values
    color = mix(color + accumulatedLight / pow(far, 0.75), color, max(blindness, darknessFactor));
}
