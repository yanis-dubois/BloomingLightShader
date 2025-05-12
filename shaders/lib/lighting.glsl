vec4 doLighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, vec3 tangent, vec3 bitangent, vec3 normalMap, vec3 worldSpacePosition, vec3 unanimatedWorldPosition, 
                float smoothness, float reflectance, float subsurface, float ambientSkyLightIntensity, float blockLightIntensity, float ambientOcclusion, float subsurfaceScattering, float emissivness) {

    vec3 skyLightColor = getSkyLightColor();

    // directions and angles 
    vec3 worldSpacelightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(worldSpacelightDirection, normalMap);
    float ambientLightDirectionDotNormal = dot(normal, normalMap);
    #if PIXELATED_SPECULAR > 0
        vec3 worldSpaceViewDirection = normalize(cameraPosition - voxelize(unanimatedWorldPosition, normal));
    #else
        vec3 worldSpaceViewDirection = normalize(cameraPosition - unanimatedWorldPosition);
    #endif
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);

    // -- shadow -- //
    // apply offset in normal direction to avoid self shadowing
    vec3 offsetWorldSpacePosition = unanimatedWorldPosition + normal * 0.2;
    // pixelize if needed
    #if PIXELATED_SHADOW > 0
        offsetWorldSpacePosition = voxelize(offsetWorldSpacePosition, normal);
    #endif
    // add increasing offset in normal direction when further from player (avoid shadow acne)
    float offsetAmplitude = clamp(distanceFromCamera / startShadowDecrease, 0.0, 1.0);
    offsetWorldSpacePosition += normal * offsetAmplitude;
    // get shadow
    vec4 shadow = vec4(0.0);
    if (distanceFromCamera < endShadowDecrease)
        #if PIXELATED_SHADOW > 0
            shadow = getSoftShadow(uv, offsetWorldSpacePosition, tangent, bitangent, ambientSkyLightIntensity);
        #else
            shadow = getSoftShadow(uv, offsetWorldSpacePosition);
        #endif
    // fade into the distance
    float shadow_fade = 1.0 - map(distanceFromCamera, startShadowDecrease, endShadowDecrease, 0.0, 1.0);
    shadow *= shadow_fade;

    // -- lighting -- //

    // -- light factors
    float ambientSkyLightFactor = 0.6;
    float ambientLightFactor = 0.0125;
    float faceTweak = 1.0;
    float dayNightBlend = getDayNightBlend();
    float darknessExponent = 10.0;
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    faceTweak = mix(faceTweak, 0.55, smoothstep(0.8, 0.9, abs(dot(normal, eastDirection))));
    faceTweak = mix(faceTweak, 0.8, smoothstep(0.8, 0.9, abs(dot(normal, southDirection))));
    faceTweak = mix(faceTweak, 0.3, smoothstep(0.8, 0.9, dot(normal, downDirection)));
    float directSkyLightFactor = mix(1.0, 0.2, abs(dot(normal, southDirection)));

    // -- direct sky light
    float directSkyLightIntensity = max(lightDirectionDotNormal, 0.0);
    #ifdef TRANSPARENT
        directSkyLightIntensity = max(2.0 * directSkyLightIntensity, 0.1);
    #endif
    // subsurface scattering
    #if SUBSURFACE_TYPE == 1
        // subsurface diffuse part
        if (subsurfaceScattering > 0.0) {
            float subsurface_fade = 1.0 - map(distanceFromCamera, 0.8 * startShadowDecrease, 0.8 * endShadowDecrease, 0.0, 1.0);
            float subsurfaceDirectSkyLightIntensity = smoothstep(0.0, 0.5, abs(lightDirectionDotNormal));
            directSkyLightIntensity = mix(directSkyLightIntensity, subsurfaceDirectSkyLightIntensity, subsurface_fade);
            directSkyLightIntensity = mix(directSkyLightIntensity, 1.0, dot(worldSpacelightDirection, vec3(0.0, 1.0, 0.0)));
        }
    #endif
    // tweak for south and north facing fragment
    directSkyLightIntensity = mix(directSkyLightIntensity, 0.15, abs(dot(normalMap, southDirection)));
    // reduce contribution if no ambiant sky light (avoid cave leak)
    directSkyLightIntensity *= map(smoothstep(0.0, 0.33, ambientSkyLightIntensity), 0.0, 1.0, 0.1, 1.0);
    // reduce contribution as it rains
    directSkyLightIntensity *= mix(1.0, 0.2, rainStrength);
    // reduce contribution during day-night transition
    directSkyLightIntensity *= dayNightBlend;
    // face tweak
    directSkyLightIntensity *= faceTweak;
    // split toning
    #if SPLIT_TONING > 0
        vec3 splitToningColor = getLightness(skyLightColor) * getShadowLightColor();
        skyLightColor = mix(splitToningColor, skyLightColor, smoothstep(0.0, 0.5, directSkyLightIntensity * (1 - shadow.a)));
    #endif
    // apply darkness
    directSkyLightIntensity = mix(directSkyLightIntensity, 0.0, darknessFactor);
    // apply sky light color
    vec3 directSkyLight = directSkyLightIntensity * skyLightColor;
    // apply shadow
    directSkyLight = mix(directSkyLight, directSkyLight * shadow.rgb, shadow.a);

    // -- ambient sky light
    // apply normalmap
    ambientSkyLightFactor *= max(ambientLightDirectionDotNormal, 0.0);
    // apply darkness
    ambientSkyLightIntensity = mix(ambientSkyLightIntensity, 0.0, darknessFactor);
    // get light color
    vec3 ambientSkyLight = faceTweak * ambientSkyLightFactor * skyLightColor * ambientSkyLightIntensity;

    // -- block light
    // apply normalmap
    blockLightIntensity *= max(ambientLightDirectionDotNormal, 0.0);
    // apply darkness
    blockLightIntensity = mix(blockLightIntensity, 0.00001 * smoothstep(0.99, 1.0, emissivness), darknessLightFactor);
    emissivness = mix(emissivness, 0.00001 * smoothstep(0.99, 1.0, emissivness), darknessLightFactor);
    // get light color
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity, emissivness);
    vec3 blockLight = faceTweak * blockLightColor * mix(1.0, blockLightIntensity, darknessFactor);

    // -- ambient light
    vec3 ambiantLightColor = light10000K;
    // apply normalmap
    ambientLightFactor *= max(ambientLightDirectionDotNormal, 0.0);
    // apply darkness
    ambientLightFactor = mix(ambientLightFactor, 0.0, smoothstep(0.0, 0.25, darknessLightFactor));
    // get light color
    vec3 ambientLight = faceTweak * ambientLightFactor * ambiantLightColor * (1.0 - ambientSkyLightIntensity);

    // -- filter underwater light
    if (isEyeInWater == 1) {
        vec3 waterColor = mix(getWaterFogColor(), vec3(1.0), 0.5);
        directSkyLight = directSkyLight * waterColor;
        ambientSkyLight = ambientSkyLight * waterColor;
        blockLight = blockLight * waterColor;
        ambientLight = ambientLight * waterColor;
    }

    // -- ambient occlusion
    #if PBR_TYPE > 0
        directSkyLight *= ambientOcclusion;
        blockLight *= ambientOcclusion;
        ambientSkyLight *= ambientOcclusion;
        ambientLight *= ambientOcclusion;
    #else
        ambientOcclusion = smoothstep(0.0, 0.9, ambientOcclusion);
        directSkyLight *= ambientOcclusion * 0.75 + 0.25;
        blockLight *= ambientOcclusion * 0.75 + 0.25;
        ambientSkyLight *= ambientOcclusion * 0.25 + 0.75;
        ambientLight *= ambientOcclusion * 0.25 + 0.75;
    #endif

    // -- BRDF -- //
    // -- diffuse
    vec3 light = directSkyLight + ambientSkyLight + blockLight + ambientLight;
    // apply night vision
    light = mix(light, pow(light, vec3(0.33)), nightVision);
    // diffuse model
    vec3 color = albedo * light;
    // -- specular
    if (smoothness > 0.1) {
        vec3 subsurfaceSpecular = vec3(0.0);

        // subsurface transmission highlight
        #if SUBSURFACE_TYPE > 0
            if (subsurfaceScattering > 0.0) {
                float specularFade = map(distanceFromCamera, endShadowDecrease * 0.6, startShadowDecrease * 0.6, 0.0, 1.0);
                subsurfaceSpecular = specularFade * specularSubsurfaceBRDF(worldSpaceViewDirection, worldSpacelightDirection, albedo);
            }
        #endif

        // specular reflection
        vec3 specular = CookTorranceBRDF(normalMap, worldSpaceViewDirection, worldSpacelightDirection, albedo, smoothness, reflectance);

        // add specular contribution
        color += directSkyLight * (specular + subsurfaceSpecular);
    }
    // -- fresnel
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE && defined TRANSPARENT
        float fresnel = fresnel(worldSpaceViewDirection, normalMap, reflectance);
        transparency = max(transparency, fresnel);
    #endif
    // -- emissivness
    color = mix(color, albedo, emissivness);

    return vec4(color, transparency);
}

vec4 doDHLighting(vec3 albedo, float transparency, vec3 normal, vec3 worldSpacePosition, 
                float smoothness, float reflectance, float ambientSkyLightIntensity, float blockLightIntensity, float emissivness) {

    vec3 skyLightColor = getSkyLightColor();

    // directions and angles 
    vec3 worldSpacelightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(worldSpacelightDirection, normal);
    vec3 worldSpaceViewDirection = normalize(cameraPosition - worldSpacePosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);

    // -- lighting -- //

    // -- light factors
    float ambientSkyLightFactor = 0.6;
    float ambientLightFactor = 0.0125;
    float faceTweak = 1.0;
    float dayNightBlend = getDayNightBlend();
    float darknessExponent = 10.0;
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    faceTweak = mix(faceTweak, 0.55, smoothstep(0.8, 0.9, abs(dot(normal, eastDirection))));
    faceTweak = mix(faceTweak, 0.8, smoothstep(0.8, 0.9, abs(dot(normal, southDirection))));
    faceTweak = mix(faceTweak, 0.3, smoothstep(0.8, 0.9, dot(normal, downDirection)));
    float directSkyLightFactor = mix(1.0, 0.2, abs(dot(normal, southDirection)));

    // -- direct sky light
    float directSkyLightIntensity = max(lightDirectionDotNormal, 0.0);
    #ifdef TRANSPARENT
        directSkyLightIntensity = max(2.0 * directSkyLightIntensity, 0.1);
    #endif
    // tweak for south and north facing fragment
    directSkyLightIntensity = mix(directSkyLightIntensity, 0.15, abs(dot(normal, southDirection)));
    // reduce contribution if no ambiant sky light (avoid cave leak)
    directSkyLightIntensity *= map(smoothstep(0.0, 0.33, ambientSkyLightIntensity), 0.0, 1.0, 0.1, 1.0);
    // reduce contribution as it rains
    directSkyLightIntensity *= mix(1.0, 0.2, rainStrength);
    // reduce contribution during day-night transition
    directSkyLightIntensity *= dayNightBlend;
    // face tweak
    directSkyLightIntensity *= faceTweak;
    // split toning
    #if SPLIT_TONING > 0
        vec3 splitToningColor = getLightness(skyLightColor) * getShadowLightColor();
        skyLightColor = mix(splitToningColor, skyLightColor, smoothstep(0.0, 0.5, directSkyLightIntensity));
    #endif
    // apply darkness
    directSkyLightIntensity = mix(directSkyLightIntensity, 0.0, darknessFactor);
    // apply sky light color
    vec3 directSkyLight = directSkyLightIntensity * skyLightColor;

    // -- ambient sky light
    // apply darkness
    ambientSkyLightIntensity = mix(ambientSkyLightIntensity, 0.0, darknessFactor);
    // get light color
    vec3 ambientSkyLight = faceTweak * ambientSkyLightFactor * skyLightColor * ambientSkyLightIntensity;

    // -- block light
    // apply darkness
    blockLightIntensity = mix(blockLightIntensity, 0.00001 * smoothstep(0.99, 1.0, emissivness), darknessLightFactor);
    emissivness = mix(emissivness, 0.00001 * smoothstep(0.99, 1.0, emissivness), darknessLightFactor);
    // get light color
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity, emissivness);
    vec3 blockLight = faceTweak * blockLightColor * mix(1.0, blockLightIntensity, darknessFactor);

    // -- ambient light
    vec3 ambiantLightColor = light10000K;
    // apply darkness
    ambientLightFactor = mix(ambientLightFactor, 0.0, smoothstep(0.0, 0.25, darknessLightFactor));
    // get light color
    vec3 ambientLight = faceTweak * ambientLightFactor * ambiantLightColor * (1.0 - ambientSkyLightIntensity);

    // -- filter underwater light
    if (isEyeInWater == 1) {
        vec3 waterColor = mix(getWaterFogColor(), vec3(1.0), 0.5);
        directSkyLight = directSkyLight * waterColor;
        ambientSkyLight = ambientSkyLight * waterColor;
        blockLight = blockLight * waterColor;
        ambientLight = ambientLight * waterColor;
    }

    // -- BRDF -- //
    // -- diffuse
    vec3 light = directSkyLight + ambientSkyLight + blockLight + ambientLight;
    // apply night vision
    light = mix(light, pow(light, vec3(0.33)), nightVision);
    // diffuse model
    vec3 color = albedo * light;
    // -- specular
    if (0.1 < smoothness) {
        float specularFade = map(distanceFromCamera, endShadowDecrease * 0.6, startShadowDecrease * 0.6, 0.0, 1.0);
        vec3 specular = vec3(0.0);

        // specular reflection
        specular += CookTorranceBRDF(normal, worldSpaceViewDirection, worldSpacelightDirection, albedo, smoothness, reflectance);

        // add specular contribution
        color += directSkyLight * specular;
    }
    // -- fresnel
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE && defined TRANSPARENT
        float fresnel = fresnel(worldSpaceViewDirection, normal, reflectance);
        transparency = max(transparency, fresnel);
    #endif

    return vec4(color, transparency);
}
