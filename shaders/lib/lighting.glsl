float getDayNightBlend() {
    return map(shadowAngle, 0.0, 0.02, 0, 1) * map(shadowAngle, 0.5, 0.48, 0, 1);
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

    // decrease volumetric light effect as light source and view vector are align
    // -> avoid player shadow monster 
    vec3 worldSpaceLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float LdotV = dot(worldSpaceViewDirection, worldSpaceLightDirection);
    float attenuationFactor = pow(LdotV * 0.5 + 0.5, 0.35);
    // decrease volumetric light that is added on sky
    // which is even truer the further up you look
    float VdotU = dot(worldSpaceViewDirection, vec3(0,1,0));
    float invVdotU = 1 - max(VdotU, 0);
    attenuationFactor *= invVdotU * invVdotU;

    // init loop
    vec3 opaqueAccumulatedLight = vec3(0), transparentAccumulatedLight = vec3(0);
    float stepsCount = clamp(clampedMaxDistance * VOLUMETRIC_LIGHT_RESOLUTION, VOLUMETRIC_LIGHT_MIN_SAMPLE, VOLUMETRIC_LIGHT_MAX_SAMPLE); // nb steps (minimum 16)
    float stepSize = clampedMaxDistance / stepsCount; // born max distance and divide by step count
    vec2 seed = uv;// + (float(frameCounter) / 720719.0);
    float randomizedStepSize = stepSize * pseudoRandom(seed);
    vec3 rayWorldSpacePosition = cameraPosition;
    float rayDistance = 0;
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
    opaqueAccumulatedLight *= skyLightColor * mix(1, 0.5, rainStrength) * getDayNightBlend();
    transparentAccumulatedLight *= skyLightColor * mix(1, 0.5, rainStrength) * getDayNightBlend();

    // write values
    opaqueColorData.rgb += opaqueAccumulatedLight / pow(far, 0.75);
    transparentColorData.rgb += transparentAccumulatedLight / pow(far, 0.75);
}

vec4 lighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, float depth, float smoothness, float reflectance, float subsurface,
              float ambientSkyLightIntensity, float blockLightIntensity, float emissivness, float ambient_occlusion, bool isTransparent, float type) {

    // TODO: SSAO
    float occlusion = 1;

    // directions and angles 
    vec3 worldSpacelightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(worldSpacelightDirection, normal);
    vec3 worldSpacePosition = viewToWorld(screenToView(uv, depth));
    vec3 worldSpaceViewDirection = normalize(cameraPosition - worldSpacePosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    float normalizedLinearDepth = distanceFromCamera / far;
    float cosTheta = dot(worldSpaceViewDirection, normal);

    /* shadow */
    // offset position in normal direction (avoid self shadowing)
    vec3 offsetWorldSpacePosition = worldSpacePosition + normal * 0.1; // 0.1
    vec3 offsetScreenSpacePosition = worldToScreen(offsetWorldSpacePosition);
    // get shadow
    vec4 shadow = vec4(0);
    if (distanceFromCamera < endShadowDecrease)
        shadow = getSoftShadow(uv, offsetWorldSpacePosition);
    // fade into the distance
    float shadow_fade = 1 - map(distanceFromCamera, startShadowDecrease, endShadowDecrease, 0, 1);
    shadow *= shadow_fade;

    /* lighting */
    // -- light factors
    float skyDirectLightFactor = max(lightDirectionDotNormal, 0);
    float faceTweak = 1;
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    faceTweak = mix(faceTweak, 0.6, smoothstep(0.8, 0.9, abs(dot(normal, vec3(1,0,0)))));
    faceTweak = mix(faceTweak, 0.8, smoothstep(0.8, 0.9, abs(dot(normal, vec3(0,0,1)))));
    faceTweak = mix(faceTweak, 0.4, smoothstep(0.8, 0.9, (dot(normal, vec3(0,-1,0)))));
    skyDirectLightFactor = mix(skyDirectLightFactor, 0.2, abs(dot(normal, vec3(0,0,1))));
    // -- direct sky light
    vec3 skyDirectLight = skyLightColor * skyDirectLightFactor;
    // subsurface scattering
    if (SUBSURFACE_TYPE == 1 && ambient_occlusion > 0) {
        float subsurface_fade = map(distanceFromCamera, endShadowDecrease*0.8, startShadowDecrease*0.8, 0.2, 1);
        skyDirectLight = max(lightDirectionDotNormal, subsurface_fade) * skyLightColor;
        ambient_occlusion = smoothstep(0.1, 0.9, ambient_occlusion);
        skyDirectLight *= ambient_occlusion * (abs(lightDirectionDotNormal)*0.5 + 0.5);
    }
    // reduce contribution if no ambiant sky light (avoid cave leak)
    if (ambientSkyLightIntensity < 0.01) skyDirectLight *= 0;
    // reduce contribution as it rains
    skyDirectLight *= mix(1, 0.5, rainStrength);
    // reduce contribution during day-night transition
    skyDirectLight *= getDayNightBlend();
    // apply shadow
    skyDirectLight = mix(skyDirectLight, skyDirectLight * shadow.rgb, shadow.a);
    // -- ambient sky light
    float ambientSkyLightFactor = isTransparent ? 0.6 : 0.3;
    vec3 ambientSkyLight = faceTweak * ambientSkyLightFactor * skyLightColor * ambientSkyLightIntensity;
    // -- block light
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity, emissivness);
    vec3 blockLight = faceTweak * blockLightColor;
    // -- ambient light
    float ambientLightFactor = 0.007;
    vec3 ambiantLightColor = shadow_10000K;
    vec3 ambientLight = faceTweak * ambientLightFactor * ambiantLightColor * (1 - ambientSkyLightIntensity);
    // -- filter underwater light
    if (!isTransparent && (isEyeInWater==1 || isWater(texture2D(colortex7, uv).x))) {
        skyDirectLight *= smoothstep(0, 0.5, ambientSkyLightIntensity);
        vec3 waterColor = mix(getFogColor(true), vec3(0.5), 0.5);
        skyDirectLight = getLightness(skyDirectLight) * waterColor;
        ambientSkyLight = getLightness(ambientSkyLight) * waterColor;
        blockLight = getLightness(blockLight) * waterColor;
        ambientLight = getLightness(ambientLight) * waterColor * 1.5;
    }

    /* BRDF */
    // diffuse
    vec3 light = skyDirectLight + ambientSkyLight + blockLight + ambientLight;
    vec3 color = albedo * occlusion * light;
    // specular (not reflective)
    if (0.1 < smoothness && smoothness < 0.5) {
        float roughness = 1.0 - smoothness;
        vec3 n = normal;

        // specular subsurface
        if (SUBSURFACE_TYPE == 1 && ambient_occlusion > 0) {
            n = vec3(0,1,0); // high intensity when light source is at grazing angle, low otherwise.
            skyDirectLight *= shadow_fade; // atenuate on distance 
        }

        // calculate specular reflection
        vec3 BRDF = CookTorranceBRDF(n, worldSpaceViewDirection, worldSpacelightDirection, albedo, roughness, reflectance);
        BRDF *= 25; // intensity correction
        color += BRDF * skyDirectLight;
    }

    /* fog */
    if (!isParticle(type))
        color = foggify(color, worldSpacePosition, normalizedLinearDepth);

    return vec4(color, transparency);
}
