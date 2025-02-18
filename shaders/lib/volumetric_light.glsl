void volumetricLighting(vec2 uv, float depthAll, float depthOpaque, float ambientSkyLightIntensity, bool isWater,
                        inout vec4 opaqueColorData, inout vec4 transparentColorData) {

    if (VOLUMETRIC_LIGHT_TYPE == 0)
        return;

    vec3 skyLightColor = getSkyLightColor();

    // parameters
    // float absorptionCoefficient = 0.0;
    float scatteringCoefficient = 0.0;
    float sunIntensity = VOLUMETRIC_LIGHT_INTENSITY;

    // does ray as a medium change in its trajectory ?
    bool asMediumChange = isWater && depthAll<depthOpaque;

    // distances
    vec3 opaqueWorldSpacePosition = viewToWorld(screenToView(uv, depthOpaque));
    vec3 transparentWorldSpacePosition = viewToWorld(screenToView(uv, depthAll));
    float opaqueFragmentDistance = distance(cameraPosition, opaqueWorldSpacePosition);
    float transparentFragmentDistance = distance(cameraPosition, transparentWorldSpacePosition);
    float clampedMaxDistance = clamp(opaqueFragmentDistance, 0.001, endShadowDecrease);
    // direction
    vec3 worldSpaceViewDirection = normalize(opaqueWorldSpacePosition - cameraPosition);

    // decrease volumetric light effect as light source and view vector are align
    // -> avoid player shadow monster 
    vec3 worldSpaceLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float LdotV = dot(worldSpaceViewDirection, worldSpaceLightDirection);
    float attenuationFactor = pow(LdotV * 0.5 + 0.5, 0.35);

    // decrease volumetric light that is added on sky
    // which is even truer the further up you look
    float VdotU = dot(worldSpaceViewDirection, upDirection);
    float invVdotU = 1.0 - max(VdotU, 0.0);
    attenuationFactor *= invVdotU * invVdotU;

    // init loop
    vec3 opaqueAccumulatedLight = vec3(0.0), transparentAccumulatedLight = vec3(0.0);
    float stepsCount = clamp(clampedMaxDistance * VOLUMETRIC_LIGHT_RESOLUTION, VOLUMETRIC_LIGHT_MIN_SAMPLE, VOLUMETRIC_LIGHT_MAX_SAMPLE); // nb steps (minimum 16)
    float stepSize = clampedMaxDistance / stepsCount; // clamp max distance and divide by step count
    vec2 seed = uv;
    float randomizedStepSize = stepSize * pseudoRandom(seed);
    vec3 rayWorldSpacePosition = cameraPosition;
    float rayDistance = 0.0;
    rayWorldSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    bool transparentHit = false;

    // loop
    for (int i=0; i<stepsCount; ++i) {
        rayDistance = distance(cameraPosition, rayWorldSpacePosition);

        // ray goes beneath block
        if (!transparentHit && rayDistance>transparentFragmentDistance) {
            transparentHit = true;
            transparentAccumulatedLight = opaqueAccumulatedLight;
        }
        if (rayDistance>opaqueFragmentDistance) {
            break;
        }

        // if in camera in water and ray inside it, or camera outside water but ray goes beneath it
        bool isInWater = 
               (!asMediumChange && isEyeInWater==1) 
            || (asMediumChange && isEyeInWater==1 && rayDistance<transparentFragmentDistance) 
            || (asMediumChange && isEyeInWater!=1 && rayDistance>transparentFragmentDistance);

        // density 
        // water density 
        if (isInWater && isEyeInWater==1) {
            // when camera inside water (broke rendering equation by creating energy, but it looks better)
            if (isEyeInWater==1) {
                scatteringCoefficient = 20.0;
            }
            // when camera outside water (avoid adding energy)
            else {
                scatteringCoefficient = 1.0;
            }
        }
        // air density depending at altitude
        else {
            scatteringCoefficient = map(getFogDensity(rayWorldSpacePosition.y, false), minimumFogDensity, maximumFogDensity, 0.1, 1.0);
        }

        if (sunAngle > 0.5) {
            scatteringCoefficient *= isInWater ? 0.5 : 0.1;
        }

        // get shadow
        vec4 shadowClipPos = playerToShadowClip(worldToPlayer(rayWorldSpacePosition));
        vec4 shadow = getShadow(shadowClipPos);
        vec3 shadowedLight = mix(shadow.rgb, vec3(0.0), shadow.a);

        // compute inscattered light 
        // float scattering = exp(-absorptionCoefficient * rayDistance);
        vec3 inscatteredLight = shadowedLight * scatteringCoefficient * sunIntensity;
        // integrate over distance
        inscatteredLight *= randomizedStepSize;
        inscatteredLight *= getFogColor(isInWater);

        // add light contribution
        opaqueAccumulatedLight += inscatteredLight;

        // go a step further
        seed ++;
        randomizedStepSize = stepSize * pseudoRandom(seed);
        randomizedStepSize = stepSize + 0.1 * pseudoRandom(seed);
        rayWorldSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    }

    // in case ray didn't goes through water
    if (!transparentHit) {
        transparentAccumulatedLight = opaqueAccumulatedLight;
    }

    // apply attenuation
    opaqueAccumulatedLight *= attenuationFactor;
    transparentAccumulatedLight *= attenuationFactor;

    // color adjustment & day-night blend
    opaqueAccumulatedLight *= skyLightColor * mix(1.0, 0.5, rainStrength) * getDayNightBlend();
    transparentAccumulatedLight *= skyLightColor * mix(1.0, 0.5, rainStrength) * getDayNightBlend();

    // write values
    opaqueColorData.rgb += opaqueAccumulatedLight / pow(far, 0.75);
    transparentColorData.rgb += transparentAccumulatedLight / pow(far, 0.75);
}
