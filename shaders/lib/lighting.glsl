float getDayNightBlend() {
    return map(shadowAngle, 0.0, 0.01, 0, 1) * map(shadowAngle, 0.5, 0.49, 0, 1);
}

void volumetricLighting(vec2 uv, float depthAll, float depthOpaque, float ambientSkyLightIntensity, bool isWater,
                        inout vec4 opaqueColorData, inout vec4 transparentColorData) {
    
    if (VOLUMETRIC_LIGHT_TYPE == 0)
        return;
    
    // parameters
    float absorptionCoefficient = 0.0;
    float scatteringCoefficient = 0;
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

    // init loop
    vec3 opaqueAccumulatedLight = vec3(0), transparentAccumulatedLight = vec3(0);
    float stepsCount = clamp(clampedMaxDistance * VOLUMETRIC_LIGHT_RESOLUTION, 16, 64); // nb steps (minimum 16)
    float stepSize = clampedMaxDistance / stepsCount; // born max distance and divide by step count
    vec2 seed = uv + (float(frameCounter) / 720719.0);
    float randomizedStepSize = stepSize * pseudoRandom(seed);
    vec3 rayWorldSpacePosition = cameraPosition;
    float rayDistance = 0;
    rayWorldSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    bool transparentHit = false;

    // tweak for caves ??
    float cameraSkyLight = float(eyeBrightnessSmooth.y) / 240.0;

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
                scatteringCoefficient = 20;
            }
            // when camera outside water (avoid adding energy)
            else {
                scatteringCoefficient = 1;
            }
        }
        // air density depending at altitude
        else {
            scatteringCoefficient = map(getFogDensity(rayWorldSpacePosition.y, false), minimumFogDensity, maximumFogDensity, 0.1, 1);
        }

        if (sunAngle > 0.5) {
            scatteringCoefficient *= isInWater ? 0.5 : 0.1;
        }

        // get shadow
        vec4 shadowClipPos = playerToShadowClip(worldToPlayer(rayWorldSpacePosition));
        vec4 shadow = getShadow(shadowClipPos);
        vec3 shadowedLight = mix(shadow.rgb, vec3(0), shadow.a);

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
        rayWorldSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    }

    // in case ray didn't goes through water
    if (!transparentHit) {
        transparentAccumulatedLight = opaqueAccumulatedLight;
    }

    // decrease volumetric light effect as light source and view vector are align
    // -> avoid player shadow monster 
    vec3 worldSpaceLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float LdotV = dot(worldSpaceViewDirection, worldSpaceLightDirection);
    float attenuationFactor = pow(LdotV * 0.5 + 0.5, 0.35);
    opaqueAccumulatedLight *= attenuationFactor;
    transparentAccumulatedLight *= attenuationFactor;

    // color adjustment & day-night blend
    opaqueAccumulatedLight *= skyLightColor * rainFactor * getDayNightBlend();
    transparentAccumulatedLight *= skyLightColor * rainFactor * getDayNightBlend();

    // write values
    opaqueColorData.rgb += opaqueAccumulatedLight / pow(far, 0.75);
    transparentColorData.rgb += transparentAccumulatedLight / pow(far, 0.75);
}

vec3 foggify(vec3 color, vec3 worldSpacePosition, float normalizedLinearDepth) {

    // custom fog
    if (FOG_TYPE == 2) {
        float fogDensity = getFogDensity(worldSpacePosition.y, isEyeInWater==1);

        // exponential function
        float fogAmount = getFogAmount(normalizedLinearDepth, fogDensity);
        color = mix(color, getFogColor(isEyeInWater==1) * getSkyLightColor(), fogAmount);
    }
    // vanilla fog (not applied when camera is under water) // TODO: remplacer fogColor 
    if (FOG_TYPE == 1 || (FOG_TYPE == 2 && isEyeInWater!=1)) {
        // linear function 
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float vanillaFogBlend = clamp((distanceFromCameraXZ - fogStart) / (fogEnd - fogStart), 0, 1);
        color = mix(color, getFogColor(isEyeInWater==1) * getSkyLightColor(), vanillaFogBlend);
    }

    return color;
}

vec4 lighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, float depth, float smoothness, float reflectance, float subsurface,
              float ambientSkyLightIntensity, float blockLightIntensity, float emissivness, float ambient_occlusion, bool isTransparent) {

    float ambientFactor = 0.2;

    // TODO: SSAO
    float occlusion = 1;
    
    // directions and angles 
    vec3 lightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(lightDirectionWorldSpace, normal);
    vec3 worldSpacePosition = viewToWorld(screenToView(uv, depth));
    vec3 worldSpaceViewDirection = normalize(cameraPosition - worldSpacePosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    float normalizedLinearDepth = distanceFromCamera / far;
    float cosTheta = dot(worldSpaceViewDirection, normal);

    /* shadow */
    vec4 shadow = vec4(0);
    if (distanceFromCamera < endShadowDecrease)
        shadow = getSoftShadow(uv, depth, gbufferProjectionInverse, gbufferModelViewInverse);
    // fade into the distance
    float shadow_fade = 1 - map(distanceFromCamera, startShadowDecrease, endShadowDecrease, 0, 1);
    shadow *= shadow_fade; 
    // emissive block don't have shadows on them
    shadow *= 1-emissivness;

    /* lighting */
    // direct sky light
    vec3 skyDirectLight = max(lightDirectionDotNormal, 0) * skyLightColor;
    // subsurface scattering
    if (SUBSURFACE_TYPE == 1 && ambient_occlusion > 0) {
        float subsurface_fade = map(distanceFromCamera, endShadowDecrease*0.8, startShadowDecrease*0.8, 0.2, 1);
        skyDirectLight = max(lightDirectionDotNormal, subsurface_fade) * skyLightColor;
        skyDirectLight *= ambient_occlusion * (abs(lightDirectionDotNormal)*0.5 + 0.5);
    }
    skyDirectLight *= rainFactor * getDayNightBlend(); // reduce contribution as it rains or during day-night transition
    skyDirectLight = mix(skyDirectLight, skyDirectLight * shadow.rgb, shadow.a); // apply shadow
    // ambient sky light
    vec3 ambientSkyLight = ambientFactor * skyLightColor * ambientSkyLightIntensity;
    // block light
    vec3 blockLight = blockLightColor * blockLightIntensity;
    // filter underwater light
    if (!isTransparent && (isEyeInWater==1 || isWater(texture2D(colortex7, uv).x))) {
        skyDirectLight *= map(ambientSkyLightIntensity, 0, 1, 0.01, 1);
        vec3 waterColor = mix(getFogColor(true), vec3(0.5), 0.5);
        skyDirectLight = getLightness(skyDirectLight) * waterColor;
        ambientSkyLight = getLightness(ambientSkyLight) * waterColor;
        blockLight = getLightness(blockLight) * waterColor;
    }
    
    // perfect diffuse
    vec3 color = albedo * occlusion * (skyDirectLight + ambientSkyLight + blockLight);

    /* BRDF */
    // float roughness = pow(1.0 - smoothness, 2.0);
    // vec3 BRDF = albedo * (ambientSkyLight + blockLight) + skyDirectLight * brdf(LightDirectionWorldSpace, viewDirectionWorldSpace, normal, albedo, roughness, reflectance);

    /* fresnel */
    transparency = max(transparency, schlick(reflectance, cosTheta));

    /* fog */
    color = foggify(color, worldSpacePosition, normalizedLinearDepth);

    return vec4(color, transparency);
}
