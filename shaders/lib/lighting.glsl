vec4 doLighting(int id, vec2 pixelationOffset, vec2 uv, vec3 albedo, float transparency, vec3 normal, vec3 tangent, vec3 bitangent, vec3 normalMap, vec3 worldSpacePosition, vec3 unanimatedWorldPosition, 
                float smoothness, float reflectance, float subsurface, float ambientSkyLightIntensity, float blockLightIntensity, float vanillaAmbientOcclusion, float ambientOcclusion, float ambientOcclusionPBR, float subsurfaceScattering, float emissivness) {

    vec3 skyLightColor = getSkyLightColor();

    // pixelated block light
    #if defined TERRAIN && PIXELATION_TYPE > 1 && PIXELATED_BLOCKLIGHT > 0
        vec2 texelLight = texelSnap(vec2(blockLightIntensity, ambientSkyLightIntensity), pixelationOffset);
        blockLightIntensity = texelLight.x;
        ambientSkyLightIntensity = texelLight.y;
    #endif

    // pixelated ambient occlusion
    #if defined TERRAIN && PIXELATION_TYPE > 1 && PIXELATED_AMBIENT_OCCLUSION > 0
        vec2 texelAmbientOcclusion = texelSnap(vec2(vanillaAmbientOcclusion, ambientOcclusion), pixelationOffset);
        vanillaAmbientOcclusion = texelAmbientOcclusion.x;
        ambientOcclusion = texelAmbientOcclusion.y;
    #endif

    // directions and angles 
    vec3 worldSpacelightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(worldSpacelightDirection, normalMap);
    float ambientLightDirectionDotNormal = dot(normal, normalMap);
    #if PIXELATION_TYPE > 0 && PIXELATED_SPECULAR > 0
        #if PIXELATION_TYPE > 1
            vec3 specularWorldPosition = texelSnap(unanimatedWorldPosition, pixelationOffset);
        #else
            vec3 specularWorldPosition = voxelize(unanimatedWorldPosition, normal);
        #endif
    #else
        vec3 specularWorldPosition = unanimatedWorldPosition;
    #endif
    vec3 worldSpaceViewDirection = normalize(cameraPosition - specularWorldPosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);

    // -- shadow -- //
    #ifndef NETHER
        // apply offset in normal direction to avoid self shadowing
        vec3 offsetWorldSpacePosition = unanimatedWorldPosition + normal * 0.2;
        // pixelize if needed
        #if PIXELATION_TYPE > 0 && PIXELATED_SHADOW > 0
            #if PIXELATION_TYPE > 1
                offsetWorldSpacePosition = texelSnap(offsetWorldSpacePosition, pixelationOffset);
            #else
                offsetWorldSpacePosition = voxelize(offsetWorldSpacePosition, normal);
            #endif
        #endif
        // add increasing offset in normal direction when further from player (avoid shadow acne)
        float offsetAmplitude = clamp(distanceFromCamera / startShadowDecrease, 0.0, 1.0);
        offsetWorldSpacePosition += normal * offsetAmplitude;
        // get shadow
        vec4 shadow = vec4(0.0);
        if (distanceFromCamera < shadowDistance)
            #if PIXELATION_TYPE > 0 && PIXELATED_SHADOW > 0
                shadow = getSoftShadow(uv, offsetWorldSpacePosition, tangent, bitangent, ambientSkyLightIntensity);
            #else
                shadow = getSoftShadow(uv, offsetWorldSpacePosition);
            #endif
        // fade into the distance
        float shadow_fade = 1.0 - map(distanceFromCamera, startShadowDecrease, shadowDistance, 0.0, 1.0);
        shadow *= shadow_fade;
    #endif

    // -- lighting -- //

    // -- light factors
    float ambientSkyLightFactor = 0.6;
    float faceTweak = 1.0;
    float dayNightBlend = getDayNightBlend();
    float darknessExponent = 10.0;
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    faceTweak = mix(faceTweak, 0.55, smoothstep(0.8, 0.9, abs(dot(normal, eastDirection))));
    faceTweak = mix(faceTweak, 0.8, smoothstep(0.8, 0.9, abs(dot(normal, southDirection))));
    faceTweak = mix(faceTweak, 0.3, smoothstep(0.8, 0.9, dot(normal, downDirection)));
    float directSkyLightFactor = mix(1.0, 0.2, abs(dot(normal, southDirection)));

    // -- direct sky light
    #ifdef NETHER
        vec3 directSkyLight = vec3(0.0);
    #else
        float directSkyLightIntensity = max(lightDirectionDotNormal, 0.0);
        #ifdef TRANSPARENT
            directSkyLightIntensity = max(2.0 * directSkyLightIntensity, 0.1);
        #endif
        // subsurface scattering
        #if SHADOW_TYPE > 0 && SUBSURFACE_TYPE > 0
            // subsurface diffuse part
            if (subsurfaceScattering > 0.0) {
                float subsurface_fade = 1.0 - map(distanceFromCamera, 0.8 * startShadowDecrease, 0.8 * shadowDistance, 0.0, 1.0);
                float subsurfaceDirectSkyLightIntensity = smoothstep(0.0, 0.5, abs(lightDirectionDotNormal));
                directSkyLightIntensity = mix(directSkyLightIntensity, subsurfaceDirectSkyLightIntensity, subsurface_fade);
            }
        #endif
        if (isEnviroProps(id)) {
            directSkyLightIntensity = mix(directSkyLightIntensity, 1.0, dot(worldSpacelightDirection, vec3(0.0, 1.0, 0.0)));
        }
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
        #if SPLIT_TONING > 0 && defined OVERWORLD
            vec3 splitToningColor = getLightness(skyLightColor) * getShadowLightColor();
            skyLightColor = mix(splitToningColor, skyLightColor, smoothstep(0.0, 0.5, directSkyLightIntensity * (1 - shadow.a)));
        #endif
        #if defined END
            directSkyLightIntensity = clamp(directSkyLightIntensity * 3.0, 0.0, 1.0);
        #endif
        // apply darkness
        directSkyLightIntensity = mix(directSkyLightIntensity, 0.0, darknessFactor);
        // apply sky light color
        vec3 directSkyLight = directSkyLightIntensity * skyLightColor * 1.5;
        // apply shadow
        directSkyLight = mix(directSkyLight, directSkyLight * shadow.rgb, shadow.a);
        directSkyLightIntensity *= getLightness(directSkyLight);
    #endif

    // -- ambient sky light
    #if defined OVERWORLD
        // apply normalmap
        ambientSkyLightFactor *= max(ambientLightDirectionDotNormal, 0.0);
        // apply darkness
        ambientSkyLightIntensity = mix(ambientSkyLightIntensity, 0.0, darknessFactor);
        // get light color
        vec3 ambientSkyLight = faceTweak * ambientSkyLightFactor * skyLightColor * ambientSkyLightIntensity * (1.0 - directSkyLightIntensity);
    // no ambient sky light neither in NETHER and END
    #else
        ambientSkyLightIntensity = 0.0;
        vec3 ambientSkyLight = vec3(0.0);
    #endif

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
    #if defined OVERWORLD
        float ambientLightFactor = 0.0125;
        vec3 ambiantLightColor = light10000K;
    #elif defined NETHER
        float ambientLightFactor = 0.33;
        vec3 ambiantLightColor = saturate(clamp(10.0 * fogColor, 0.0, 1.0), 0.66);
    #else
        float ambientLightFactor = 0.33;
        vec3 ambiantLightColor = skyLightColor;
    #endif
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

    // vanilla ambient occlusion
    #ifdef TERRAIN
        ambientOcclusionPBR *= vanillaAmbientOcclusion * vanillaAmbientOcclusion;
    #endif

    // -- ambient occlusion
    // PBR ao
    directSkyLight *= ambientOcclusionPBR;
    blockLight *= ambientOcclusionPBR;
    ambientSkyLight *= ambientOcclusionPBR;
    ambientLight *= ambientOcclusionPBR;
    // custom ao
    ambientOcclusion = smoothstep(0.0, 0.9, ambientOcclusion);
    directSkyLight *= ambientOcclusion * 0.75 + 0.25;
    blockLight *= ambientOcclusion * 0.75 + 0.25;
    ambientSkyLight *= ambientOcclusion * 0.5 + 0.5;
    ambientLight *= ambientOcclusion * 0.5 + 0.5;

    // -- BRDF -- //
    // -- diffuse
    vec3 light = directSkyLight + blockLight + ambientSkyLight + ambientLight;
    // apply night vision
    light = mix(light, pow(light, vec3(0.33)), nightVision);
    // diffuse model
    vec3 color = albedo * light;
    // -- specular
    #if !defined NETHER && !defined END
        if (smoothness > 0.1) {
            vec3 subsurfaceSpecular = vec3(0.0);

            // subsurface transmission highlight
            #if SHADOW_TYPE > 0 && SUBSURFACE_TYPE > 0
                if (subsurfaceScattering > 0.0) {
                    float specularFade = map(distanceFromCamera, shadowDistance * 0.6, startShadowDecrease * 0.6, 0.0, 1.0);
                    subsurfaceSpecular = specularFade * specularSubsurfaceBRDF(worldSpaceViewDirection, worldSpacelightDirection, albedo);
                }
            #endif

            // specular reflection
            vec3 specular = CookTorranceBRDF(normalMap, worldSpaceViewDirection, worldSpacelightDirection, albedo, smoothness, reflectance);

            // add specular contribution
            color += directSkyLight * (specular + subsurfaceSpecular);
        }
    #endif
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
    float faceTweak = 1.0;
    float dayNightBlend = getDayNightBlend();
    float darknessExponent = 10.0;
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    faceTweak = mix(faceTweak, 0.55, smoothstep(0.8, 0.9, abs(dot(normal, eastDirection))));
    faceTweak = mix(faceTweak, 0.8, smoothstep(0.8, 0.9, abs(dot(normal, southDirection))));
    faceTweak = mix(faceTweak, 0.3, smoothstep(0.8, 0.9, dot(normal, downDirection)));
    float directSkyLightFactor = mix(1.0, 0.2, abs(dot(normal, southDirection)));

    // -- direct sky light
    #ifdef NETHER
        vec3 directSkyLight = vec3(0.0);
    #else
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
        #if SPLIT_TONING > 0 && defined OVERWORLD
            vec3 splitToningColor = getLightness(skyLightColor) * getShadowLightColor();
            skyLightColor = mix(splitToningColor, skyLightColor, smoothstep(0.0, 0.5, directSkyLightIntensity));
        #endif
        #if defined END
            directSkyLightIntensity = clamp(directSkyLightIntensity * 3.0, 0.0, 1.0);
        #endif
        // apply darkness
        directSkyLightIntensity = mix(directSkyLightIntensity, 0.0, darknessFactor);
        // apply sky light color
        vec3 directSkyLight = directSkyLightIntensity * skyLightColor;
    #endif

    // -- ambient sky light
    #if defined OVERWORLD
        // apply darkness
        ambientSkyLightIntensity = mix(ambientSkyLightIntensity, 0.0, darknessFactor);
        // get light color
        vec3 ambientSkyLight = faceTweak * ambientSkyLightFactor * skyLightColor * ambientSkyLightIntensity;
    // no ambient sky light neither in NETHER and END
    #else
        ambientSkyLightIntensity = 0.0;
        vec3 ambientSkyLight = vec3(0.0);
    #endif

    // -- block light
    // apply darkness
    blockLightIntensity = mix(blockLightIntensity, 0.00001 * smoothstep(0.99, 1.0, emissivness), darknessLightFactor);
    emissivness = mix(emissivness, 0.00001 * smoothstep(0.99, 1.0, emissivness), darknessLightFactor);
    // get light color
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity, emissivness);
    vec3 blockLight = faceTweak * blockLightColor * mix(1.0, blockLightIntensity, darknessFactor);

    // -- ambient light
    #if defined OVERWORLD
        float ambientLightFactor = 0.0125;
        vec3 ambiantLightColor = light10000K;
    #elif defined NETHER
        float ambientLightFactor = 0.33;
        vec3 ambiantLightColor = saturate(clamp(10.0 * fogColor, 0.0, 1.0), 0.66);
    #else
        float ambientLightFactor = 0.33;
        vec3 ambiantLightColor = skyLightColor;
    #endif
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
    #if !defined NETHER && !defined END
        if (0.1 < smoothness) {
            float specularFade = map(distanceFromCamera, shadowDistance * 0.6, startShadowDecrease * 0.6, 0.0, 1.0);
            vec3 specular = vec3(0.0);

            // specular reflection
            specular += CookTorranceBRDF(normal, worldSpaceViewDirection, worldSpacelightDirection, albedo, smoothness, reflectance);

            // add specular contribution
            color += directSkyLight * specular;
        }
    #endif
    // -- fresnel
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE && defined TRANSPARENT
        float fresnel = fresnel(worldSpaceViewDirection, normal, reflectance);
        transparency = max(transparency, fresnel);
    #endif

    return vec4(color, transparency);
}
