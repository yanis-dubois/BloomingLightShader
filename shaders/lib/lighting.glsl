vec3 volumetricLighting(vec2 uv, vec3 worldPosition, vec3 worldSpaceViewDirection) {
    if (VOLUMETRIC_LIGHT_TYPE == 0)
        return vec3(0);

    // tweak for caves ??
    float cameraSkyLight = float(eyeBrightnessSmooth.y) / 240.0;
    
    // parameters
    float absorptionCoefficient = 0.00;
    float scatteringCoefficient = 0; //0=vaccumSpace 0.42=clearSky 1=fggyest 
    float sunIntensity = 1;

    float fragmentDistance = distance(cameraPosition, worldPosition);
    fragmentDistance = clamp(fragmentDistance, 0, endShadowDecrease);

    vec3 playerSpaceCameraPosition = worldToPlayer(cameraPosition);

    //
    vec3 worldSpaceLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float LdotV = dot(worldSpaceViewDirection, worldSpaceLightDirection);

    // init loop
    vec3 accumulatedLight = vec3(0);
    float stepsCount = max(fragmentDistance * VOLUMETRIC_LIGHT_RESOLUTION, 16); // nb steps (minimum 32)
    float stepSize = fragmentDistance / stepsCount;
    vec2 seed = uv + (float(frameCounter) / 720719.0);
    float randomizedStepSize = stepSize * pseudoRandom(seed);
    float weights = 0;
    vec3 rayPlayerSpacePosition = playerSpaceCameraPosition;
    rayPlayerSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    float rayDistance = distance(playerSpaceCameraPosition, rayPlayerSpacePosition);
    int count = 0;

    // loop
    for (; count<stepsCount; ++count) {
        // ray goes beneath block
        rayDistance = distance(playerSpaceCameraPosition, rayPlayerSpacePosition);
        if (rayDistance>fragmentDistance) {
            break;
        }

        float density = map(getFogDensity(rayPlayerSpacePosition.y), minimumFogDensity, maximumFogDensity, 0.1, 1);
        scatteringCoefficient = density;
        if (isEyeInWater == 1) scatteringCoefficient = 10;

        // get shadow
        vec4 shadowClipPos = playerToShadowClip(rayPlayerSpacePosition);
        vec4 shadow = getShadow(shadowClipPos);
        vec3 shadowedLight = mix(shadow.rgb, vec3(0), shadow.a);

        // compute inscattered light 
        float scattering = exp(-absorptionCoefficient * rayDistance);
        vec3 inscatteredLight = sunIntensity * shadowedLight * scatteringCoefficient * scattering;
        inscatteredLight *= randomizedStepSize;

        // add light contribution
        if (VOLUMETRIC_LIGHT_TYPE == 2) {
            scatteringCoefficient = getFogDensity(rayPlayerSpacePosition.y);
            accumulatedLight += shadowedLight * scatteringCoefficient;
            weights += scatteringCoefficient;
        }
        else accumulatedLight += inscatteredLight;

        // go a step further
        seed ++;
        randomizedStepSize = stepSize * pseudoRandom(seed);
        rayPlayerSpacePosition += worldSpaceViewDirection * randomizedStepSize;
    }

    // decrease volumetric light effect as light source and view vector are align
    // -> avoid player shadow monster 
    accumulatedLight *= pow(LdotV*0.5+0.5, 0.2);

    if (VOLUMETRIC_LIGHT_TYPE == 2) {
        float cal = clamp(1.0 / float(weights), 0, 1);
        return accumulatedLight * cal * clamp(fragmentDistance/far * scatteringCoefficient, 0, 1);
    }
    return accumulatedLight / pow(far, 0.75);
}

vec4 lighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, float depth, float smoothness, float reflectance, float subsurface,
              float ambiantSkyLightIntensity, float blockLightIntensity, float emissivness, float ambient_occlusion, bool isTransparent) {

    float ambiantFactor = 0.2;

    // TODO: SSAO
    float occlusion = 1;
    
    // directions and angles 
    vec3 lightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(lightDirectionWorldSpace, normal);
    vec3 worldSpacePosition = viewToWorld(screenToView(uv, depth));
    vec3 worldSpaceViewDirection = normalize(cameraPosition - worldSpacePosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    float linearDepth = distanceFromCamera / far;
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
    if (ambient_occlusion > 0) {
        float subsurface_fade = map(distanceFromCamera, endShadowDecrease*0.8, startShadowDecrease*0.8, 0.2, 1);
        skyDirectLight = max(lightDirectionDotNormal, subsurface_fade) * skyLightColor;
        skyDirectLight *= ambient_occlusion * (abs(lightDirectionDotNormal)*0.5 + 0.5);
    }
    skyDirectLight *= rainFactor * shadowDayNightBlend; // reduce contribution as it rains or during day-night transition
    skyDirectLight = mix(skyDirectLight, skyDirectLight * shadow.rgb, shadow.a); // apply shadow
    // ambiant sky light
    vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity;
    // block light
    if (emissivness > 0) blockLightIntensity *= 1.5;
    blockLightIntensity *= (1+emissivness);
    vec3 blockLight = blockLightColor * blockLightIntensity;
    // attenuate light underwater
    if (!isTransparent && (isEyeInWater==1 || isWater(texture2D(colortex7, uv).x))) {
        skyDirectLight *= ambiantSkyLightIntensity;
    }
    // perfect diffuse
    vec3 color = albedo * occlusion * (skyDirectLight + ambiantSkyLight + blockLight);
    // color = clamp(color * (emissivness*2 + 1), 0, 1);

    /* BRDF */
    // float roughness = pow(1.0 - smoothness, 2.0);
    // vec3 BRDF = albedo * (ambiantSkyLight + blockLight) + skyDirectLight * brdf(LightDirectionWorldSpace, viewDirectionWorldSpace, normal, albedo, roughness, reflectance);

    /* fresnel */
    transparency = max(transparency, schlick(reflectance, cosTheta));

    /* fog */
    // custom fog
    if (FOG_TYPE == 2) {
        float fogDensity = getFogDensity(worldSpacePosition.y);

        // exponential function
        float fogAmount = getFogAmount(linearDepth, fogDensity);
        color = mix(color, vec3(0.5) * skyLightColor, fogAmount);
    }
    // vanilla fog
    if (FOG_TYPE > 0) {
        // linear function 
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float vanillaFogBlend = clamp((distanceFromCameraXZ - fogStart) / (fogEnd - fogStart), 0, 1);
        color = mix(color, fog_color, vanillaFogBlend);
    }

    return vec4(color, transparency);
}
