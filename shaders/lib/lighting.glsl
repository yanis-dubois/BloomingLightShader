vec4 doLighting(int id, vec2 pixelationOffset, vec2 uv, vec2 localTextureCoordinate, vec3 textureColor, vec3 albedo, float transparency, vec3 normal, vec3 tangent, vec3 bitangent, vec3 normalMap, vec3 worldSpacePosition, vec3 unanimatedWorldPosition, 
                float smoothness, float reflectance, float ambientSkyLightIntensity, float blockLightIntensity, float vanillaAmbientOcclusion, float ambientOcclusion, float ambientOcclusionPBR, float subsurfaceScattering, inout float emissivness) {

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

    // custom ao tweak
    ambientOcclusion = smoothstep(0.0, 0.9, ambientOcclusion);
    // vanilla ao x PBR ao
    #ifdef TERRAIN
        ambientOcclusionPBR *= vanillaAmbientOcclusion * vanillaAmbientOcclusion;
    #endif

    // directions and angles 
    vec3 worldSpacelightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(worldSpacelightDirection, normalMap);
    float ambientLightDirectionDotNormal = dot(normal, normalMap);
    #if PIXELATION_TYPE > 0 && (PIXELATED_SPECULAR > 0 || PIXELATED_SHADOW > 0)
        vec3 pixelatedWorldPosition = worldToPlayer(worldSpacePosition);
        #if PIXELATION_TYPE > 1
            pixelatedWorldPosition = texelSnap(pixelatedWorldPosition, pixelationOffset); // unanimated
        #else
            pixelatedWorldPosition = voxelize(pixelatedWorldPosition, normal); // unanimated
        #endif
        pixelatedWorldPosition = playerToWorld(pixelatedWorldPosition);
    #endif
    #if PIXELATION_TYPE > 0 && PIXELATED_SPECULAR > 0
        vec3 specularWorldPosition = pixelatedWorldPosition;
    #else
        vec3 specularWorldPosition = worldSpacePosition; // unanimated
    #endif
    vec3 worldSpaceViewDirection = normalize(cameraPosition - specularWorldPosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);

    // -- shadow -- //
    #if !defined NETHER && DIRECT_LIGHTING > 0 && SHADOW_TYPE > 0
        // pixelize if needed
        #if PIXELATION_TYPE > 0 && PIXELATED_SHADOW > 0
            vec3 shadowWorldPosition = pixelatedWorldPosition;
        #else
            vec3 shadowWorldPosition = worldSpacePosition; // unanimated
        #endif
        // apply offset in normal direction to avoid self shadowing
        shadowWorldPosition += normal * 0.0625;
        // add increasing offset in normal direction when further from player (avoid shadow acne)
        float offsetAmplitude = clamp(distanceFromCamera / startShadowDecrease, 0.0, 1.0);
        shadowWorldPosition += normal * offsetAmplitude;
        // lowers shadows a bit for subsurface on props
        #if SUBSURFACE_TYPE > 0 && defined TERRAIN
            if (subsurfaceScattering > 0.0 && isProps(id)) {
                shadowWorldPosition.y += 0.25;
            }
        #endif
        // get shadow
        vec4 shadow = vec4(0.0);
        if (distanceFromCamera < shadowDistance)
            #if PIXELATION_TYPE > 0 && PIXELATED_SHADOW > 0
                shadow = getSoftShadow(uv, shadowWorldPosition, tangent, bitangent, ambientSkyLightIntensity);
            #else
                shadow = getSoftShadow(uv, shadowWorldPosition);
            #endif
        // fade into the distance
        float shadow_fade = 1.0 - map(distanceFromCamera, startShadowDecrease, shadowDistance, 0.0, 1.0);
        shadow *= shadow_fade;
    #else
        vec4 shadow = vec4(0.0);
    #endif

    // -- lighting -- //

    // -- light factors
    float ambientSkyLightFactor = 0.6;
    float faceTweak = 1.0;
    float dayNightBlend = getDayNightBlend();
    float darknessExponent = 10.0;
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    #if FACE_TWEAK > 0 && (defined TERRAIN || defined ENTITY)
        if (!isProps(id)) {
            faceTweak = mix(faceTweak, 0.75, smoothstep(0.8, 0.9, abs(dot(normal, eastDirection))));
            faceTweak = mix(faceTweak, 0.55, smoothstep(0.8, 0.9, abs(dot(normal, southDirection))));
            faceTweak = mix(faceTweak, 0.3, smoothstep(0.8, 0.9, dot(normal, downDirection)));
            // less contrast on subsurface material
            faceTweak = mix(faceTweak, faceTweak * 0.5 + 0.5, subsurfaceScattering);
        }
    #endif

    // -- direct sky light
    #if defined NETHER || DIRECT_LIGHTING == 0
        vec3 directSkyLight = vec3(0.0);
        float directSkyLightIntensity = 0.0;
    #else
        float directSkyLightIntensity = max(lightDirectionDotNormal, 0.0);
        // subsurface scattering
        #if SHADOW_TYPE > 0 && SUBSURFACE_TYPE > 0 && defined TERRAIN
            // subsurface diffuse part
            if (subsurfaceScattering > 0.0) {
                float subsurface_fade = 1.0 - map(distanceFromCamera, 0.8 * startShadowDecrease, 0.8 * shadowDistance, 0.0, 1.0);
                float subsurfaceDirectSkyLightIntensity = isProps(id) 
                    ? 1.0 
                    : abs(lightDirectionDotNormal);
                directSkyLightIntensity = mix(directSkyLightIntensity, subsurfaceDirectSkyLightIntensity, subsurfaceScattering * subsurface_fade);
            }
        #endif
        // correct direct sky light for props when it's noon
        #ifdef TERRAIN
            if (isProps(id)) {
                float directSkyLightCorrection = mix(directSkyLightIntensity, 1.0, dot(worldSpacelightDirection, vec3(0.0, 1.0, 0.0)));
                directSkyLightIntensity = mix(directSkyLightCorrection, directSkyLightIntensity, max(dot(normal, vec3(0.0, 1.0, 0.0)), 0.0));
            }
        #endif
        // tweak for south and north facing fragment of block
        if (!isProps(id)) {
            directSkyLightIntensity = mix(directSkyLightIntensity, 0.15, abs(dot(normalMap, southDirection)));
        }
        // reduce contribution if no ambiant sky light (avoid cave leak)
        directSkyLightIntensity *= map(smoothstep(0.0, 0.33, ambientSkyLightIntensity), 0.0, 1.0, 0.1, 1.0);
        // reduce contribution as it rains
        directSkyLightIntensity *= mix(1.0, 0.2, rainStrength);
        // reduce contribution during day-night transition
        directSkyLightIntensity *= dayNightBlend;
        // ambient occlusion
        #ifdef TERRAIN
            // PBR & vanilla AO
            directSkyLightIntensity *= ambientOcclusionPBR;
            // custom AO
            directSkyLightIntensity *= ambientOcclusion * 0.75 + 0.25;
        #endif
        // split toning
        #if SPLIT_TONING > 0 && defined OVERWORLD
            vec3 splitToningColor = getLightness(skyLightColor) * getShadowLightColor();
            skyLightColor = mix(splitToningColor, skyLightColor, smoothstep(0.0, 0.5, directSkyLightIntensity * (1 - shadow.a)));
        #endif
        #if defined END
            directSkyLightIntensity = clamp(directSkyLightIntensity * 1.5, 0.0, 1.0);
        #endif
        // apply darkness
        directSkyLightIntensity = mix(directSkyLightIntensity, 0.0, darknessFactor);
        // apply sky light color
        vec3 directSkyLight = directSkyLightIntensity * skyLightColor;
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
    // ambient occlusion
    #ifdef TERRAIN
        // PBR & vanilla AO
        ambientSkyLight *= ambientOcclusionPBR;
        // custom AO
        ambientSkyLight *= ambientOcclusion * 0.5 + 0.5;
    #endif

    // -- block light
    // apply normalmap
    blockLightIntensity *= max(ambientLightDirectionDotNormal, 0.0);
    // apply darkness
    blockLightIntensity = mix(blockLightIntensity, 0.0, clamp(2.0 * darknessLightFactor, 0.0, 1.0));
    // get light color
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity);
    vec3 blockLight = faceTweak * blockLightColor * mix(1.0, blockLightIntensity, darknessFactor);
    // ambient occlusion
    #ifdef TERRAIN
        // PBR & vanilla AO
        blockLight *= ambientOcclusionPBR;
        // custom AO
        blockLight *= ambientOcclusion * 0.75 + 0.25;
    #endif

    // -- ambient light
    #if AMBIENT_LIGHTING > 0
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
        // ambient occlusion
        #ifdef TERRAIN
            // PBR & vanilla AO
            ambientLight *= ambientOcclusionPBR;
            // custom AO
            ambientLight *= ambientOcclusion * 0.5 + 0.5;
        #endif
    #else
        vec3 ambientLight = vec3(0.0);
    #endif

    // -- filter underwater light
    if (isEyeInWater == 1) {
        vec3 waterColor = mix(getWaterFogColor(), vec3(1.0), 0.5);
        directSkyLight = directSkyLight * waterColor;
        ambientSkyLight = ambientSkyLight * waterColor;
        blockLight = blockLight * waterColor;
        ambientLight = ambientLight * waterColor;
    }

    float fresnel = fresnelIndex(worldSpaceViewDirection, normalMap, reflectance);

    // -- BRDF -- //
    // -- diffuse
    vec3 light = mix(0.5, 1.75, sunAngle > 0.5 ? 0.0 : 1.0) * directSkyLight + blockLight + ambientSkyLight + ambientLight;
    // apply night vision
    light = mix(light, pow(light, vec3(0.33)), nightVision);
    // diffuse model
    vec3 color = albedo * light;
    // -- specular
    #if !defined NETHER && !defined END && DIRECT_LIGHTING > 0
        vec3 specular = vec3(0.0);

        // subsurface transmission highlight
        #if SHADOW_TYPE > 0 && SUBSURFACE_TYPE > 0 && defined TERRAIN
            if (subsurfaceScattering > 0.0) {
                float specularFade = map(distanceFromCamera, shadowDistance * 0.6, startShadowDecrease * 0.6, 0.0, 1.0);
                specular = skyLightColor * subsurfaceScattering * specularFade * specularSubsurfaceBRDF(worldSpaceViewDirection, worldSpacelightDirection, albedo);
            }
        #endif

        // specular reflection
        if (isWater(id)) {
            specular += waterSpecularHighlight(normalMap, worldSpaceViewDirection, worldSpacelightDirection, textureColor, smoothness, reflectance, fresnel);
        }
        else {
            specular += skyLightColor * specularHighlight(normalMap, worldSpaceViewDirection, worldSpacelightDirection, albedo, smoothness, reflectance, fresnel);
        }

        // take shadows account
        specular = clamp(specular, 0.0, 1.0);
        specular = mix(specular, specular * shadow.rgb, shadow.a);

        // take weather account
        specular = mix(specular, 0.5 * specular, rainStrength);
        specular = mix(specular, 0.2 * specular, thunderStrength);

        // add specular contribution
        color += specular;

        // add bloom to specular reflections
        float specularFactor = smoothstep(0.0, 1.0, getLightness(specular));
        if (sunAngle > 0.5) specularFactor *= 0.9;
        emissivness = max(emissivness, specularFactor);
    #endif
    // -- fresnel
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE && defined TRANSPARENT
        transparency = max(transparency, fresnel);
    #endif
    // -- emissivness
    emissivness = mix(emissivness, 0.0, clamp(2.0 * darknessLightFactor, 0.0, 1.0));
    color = mix(color, clamp(color + albedo, 0.0, 1.0), map(emissivness, 0.0, 0.9, 0.0, 1.0));

    return vec4(color, transparency);
}

vec4 doDHLighting(int id, vec3 textureColor, vec3 albedo, float transparency, vec3 normal, vec3 worldSpacePosition, 
                float smoothness, float reflectance, float ambientSkyLightIntensity, float blockLightIntensity, inout float emissivness) {

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
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity);
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

    float fresnel = fresnelIndex(worldSpaceViewDirection, normalMap, reflectance);

    // -- BRDF -- //
    // -- diffuse
    vec3 light = mix(0.5, 1.75, sunAngle > 0.5 ? 0.0 : 1.0) * directSkyLight + ambientSkyLight + blockLight + ambientLight;
    // apply night vision
    light = mix(light, pow(light, vec3(0.33)), nightVision);
    // diffuse model
    vec3 color = albedo * light;
    // -- specular
    #if !defined NETHER && !defined END
        vec3 specular = vec3(0.0);

        // specular reflection
        if (id == DH_BLOCK_WATER) {
            specular += waterSpecularHighlight(normal, worldSpaceViewDirection, worldSpacelightDirection, textureColor, smoothness, reflectance, fresnel);
        }
        else {
            specular += skyLightColor * specularHighlight(normalMap, worldSpaceViewDirection, worldSpacelightDirection, albedo, smoothness, reflectance, fresnel);
        }

        // take weather account
        specular = mix(specular, 0.5 * specular, rainStrength);
        specular = mix(specular, 0.2 * specular, thunderStrength);

        // add specular contribution
        color += specular;

        // add bloom to specular reflections
        float specularFactor = smoothstep(0.0, 1.0, getLightness(specular));
        if (sunAngle > 0.5) specularFactor *= 0.9;
        emissivness = max(emissivness, specularFactor);
    #endif
    // -- fresnel
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE && defined TRANSPARENT
        transparency = max(transparency, fresnel);
    #endif

    return vec4(color, transparency);
}
