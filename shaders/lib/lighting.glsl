vec4 doLighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, vec3 worldSpacePosition, float smoothness, float reflectance, float subsurface,
              float ambientSkyLightIntensity, float blockLightIntensity, float emissivness, float ambient_occlusion, bool isTransparent, float type) {

    vec3 skyLightColor = getSkyLightColor();

    // directions and angles 
    vec3 worldSpacelightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(worldSpacelightDirection, normal);
    vec3 worldSpaceViewDirection = normalize(cameraPosition - worldSpacePosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    float normalizedLinearDepth = distanceFromCamera / far;
    float cosTheta = dot(worldSpaceViewDirection, normal);

    // -- shadow -- //
    // offset position in normal direction (avoid self shadowing)
    vec3 offsetWorldSpacePosition = worldSpacePosition + normal * 0.1;
    // get shadow
    vec4 shadow = vec4(0.0);
    if (distanceFromCamera < endShadowDecrease)
        shadow = getSoftShadow(uv, offsetWorldSpacePosition);
    // fade into the distance
    float shadow_fade = 1.0 - map(distanceFromCamera, startShadowDecrease, endShadowDecrease, 0.0, 1.0);
    shadow *= shadow_fade;
    shadow.a *= getDayNightBlend();

    // -- lighting -- //

    // -- light factors
    float skyDirectLightFactor = max(lightDirectionDotNormal, 0.0);
    float ambientSkyLightFactor = isTransparent ? 0.6 : 0.3;
    float ambientLightFactor = 0.007;
    float faceTweak = 1.0;
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    faceTweak = mix(faceTweak, 0.8, smoothstep(0.8, 0.9, abs(dot(normal, eastDirection))));
    faceTweak = mix(faceTweak, 0.6, smoothstep(0.8, 0.9, abs(dot(normal, southDirection))));
    faceTweak = mix(faceTweak, 0.4, smoothstep(0.8, 0.9, (dot(normal, downDirection))));
    skyDirectLightFactor = mix(skyDirectLightFactor, 0.2, abs(dot(normal, southDirection)));

    // -- direct sky light
    vec3 skyDirectLight = skyLightColor * skyDirectLightFactor;
    // subsurface scattering
    #if SUBSURFACE_TYPE == 1
        // subsurface diffuse part
        if (ambient_occlusion > 0.0) {
            float subsurface_fade = map(distanceFromCamera, 0.8 * endShadowDecrease, 0.8 * startShadowDecrease, 0.2, 1.0);
            skyDirectLight = max(lightDirectionDotNormal, subsurface_fade) * skyLightColor;
            ambient_occlusion = smoothstep(0.1, 0.9, ambient_occlusion);
            skyDirectLight *= ambient_occlusion * (abs(lightDirectionDotNormal) * 0.5 + 0.5);
        }
    #endif
    // reduce contribution if no ambiant sky light (avoid cave leak)
    skyDirectLight *= map(smoothstep(0.0, 0.5, ambientSkyLightIntensity), 0.0, 1.0, 0.05, 1.0);
    // reduce contribution as it rains
    skyDirectLight *= mix(1.0, 0.2, rainStrength);
    // reduce contribution during day-night transition
    skyDirectLight *= getDayNightBlend();
    // face tweak ?
    skyDirectLight *= map(faceTweak, 0.4, 0.8, 0.2, 1.0);
    // apply shadow
    skyDirectLight = mix(skyDirectLight, skyDirectLight * shadow.rgb, shadow.a);
    // brighten
    skyDirectLight *= 1.5;

    // -- ambient sky light
    #if SPLIT_TONING > 0
        vec3 ambientSkyLightColor = mix(skyLightColor, getShadowLightColor(), smoothstep(0.1, 0.9, shadow.a));
    #else
        vec3 ambientSkyLightColor = skyLightColor;
    #endif
    vec3 ambientSkyLight = faceTweak * ambientSkyLightFactor * ambientSkyLightColor * ambientSkyLightIntensity * (1.0 - skyDirectLight);

    // -- block light
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity, emissivness);
    vec3 blockLight = faceTweak * blockLightColor;

    // -- ambient light
    vec3 ambiantLightColor = light10000K;
    vec3 ambientLight = faceTweak * ambientLightFactor * ambiantLightColor * (1.0 - ambientSkyLightIntensity);

    // -- filter underwater light
    if (isEyeInWater==1) {
        vec3 waterColor = mix(getWaterFogColor(), vec3(0.5), 0.5);
        skyDirectLight = getLightness(skyDirectLight) * waterColor;
        ambientSkyLight = getLightness(ambientSkyLight) * waterColor;
        blockLight = getLightness(blockLight) * waterColor;
        ambientLight = getLightness(ambientLight) * waterColor * 1.5;
    }

    // -- BRDF -- //
    // -- diffuse
    vec3 light = skyDirectLight + ambientSkyLight + blockLight + ambientLight;
    vec3 color = albedo * light;
    // -- specular
    if (0.1 < smoothness && smoothness < 0.5) {
        float roughness = 1.0 - smoothness;
        float specularFade = map(distanceFromCamera, endShadowDecrease * 0.6, startShadowDecrease * 0.6, 0.0, 1.0);
        vec3 specular = vec3(0.0);

        // subsurface transmission highlight
        #if SUBSURFACE_TYPE == 1
            if (ambient_occlusion > 0.0) {
                specular = specularSubsurfaceBRDF(worldSpaceViewDirection, worldSpacelightDirection, albedo);
            }
        #endif

        // specular reflection
        specular += CookTorranceBRDF(normal, worldSpaceViewDirection, worldSpacelightDirection, albedo, roughness, reflectance);

        // add specular contribution
        color += specularFade * skyDirectLight * specular;
    }

    // -- fog -- //
    if (!isParticle(type))
       color = foggify(color, worldSpacePosition);

    return vec4(color, transparency);
}
