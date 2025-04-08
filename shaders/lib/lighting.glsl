vec4 doLighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, vec3 worldSpacePosition, vec3 unanimatedWorldPosition, float smoothness, float reflectance, float subsurface,
              float ambientSkyLightIntensity, float blockLightIntensity, float emissivness, float ambient_occlusion, bool isTransparent) {

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
    float offsetAmplitude = map(clamp(distanceFromCamera / startShadowDecrease, 0.0, 1.0), 0.0, 1.0, 0.2, 1.2);
    // add noise to offset to reduce shadow acne
    #if (SHADOW_TYPE == 1 || SHADOW_TYPE == 2) && SHADOW_RANGE > 0 && SHADOW_SAMPLES > 0
        float noise = pseudoRandom(uv + 0.14312 * frameTimeCounter);
        noise = map(noise, 0.0, 1.0, 0.5, 1.1);
    #else
        float noise = 1.0;
    #endif
    // apply offset
    vec3 offsetWorldSpacePosition = unanimatedWorldPosition + noise * normal * offsetAmplitude;
    // using voxelization to snap shadows on textures
    #if SHADOW_PIXALATED == 1
        offsetWorldSpacePosition = floor((offsetWorldSpacePosition + 0.001) * SHADOW_SNAP_RESOLUTION) / SHADOW_SNAP_RESOLUTION + 1.0/32.0;
    #endif
    // lowers shadows a bit for subsurface on foliage
    if (0.0 < ambient_occlusion && ambient_occlusion < 1.0)
        offsetWorldSpacePosition.y += 0.2;
    // get shadow
    vec4 shadow = vec4(0.0);
    if (distanceFromCamera < endShadowDecrease)
        shadow = getSoftShadow(uv, offsetWorldSpacePosition);
    // fade into the distance
    float shadow_fade = 1.0 - map(distanceFromCamera, startShadowDecrease, endShadowDecrease, 0.0, 1.0);
    shadow *= shadow_fade;

    // -- lighting -- //

    // -- light factors
    float ambientSkyLightFactor = 0.6;
    float ambientLightFactor = 0.0125;
    float faceTweak = 1.0;
    float dayNightBlend = getDayNightBlend();
    // tweak factors depending on directions (avoid seeing two faces of the same cube beeing the exact same color)
    faceTweak = mix(faceTweak, 0.55, smoothstep(0.8, 0.9, abs(dot(normal, eastDirection))));
    faceTweak = mix(faceTweak, 0.8, smoothstep(0.8, 0.9, abs(dot(normal, southDirection))));
    faceTweak = mix(faceTweak, 0.3, smoothstep(0.8, 0.9, dot(normal, downDirection)));
    float directSkyLightFactor = mix(1.0, 0.2, abs(dot(normal, southDirection)));

    // -- direct sky light
    float directSkyLightIntensity = max(lightDirectionDotNormal, 0.0);
    if (isTransparent) {
        directSkyLightIntensity = max(2.0 * directSkyLightIntensity, 0.1);
    }
    // tweak for south and north facing fragment
    directSkyLightIntensity = mix(directSkyLightIntensity, 0.15, abs(dot(normal, southDirection)));
    // subsurface scattering
    #if SUBSURFACE_TYPE == 1
        float subsurface_fade = map(distanceFromCamera, 0.8 * endShadowDecrease, 0.8 * startShadowDecrease, 0.2, 1.0);
        // subsurface diffuse part
        if (ambient_occlusion > 0.0) {
            directSkyLightIntensity = max(lightDirectionDotNormal, subsurface_fade);
            ambient_occlusion = smoothstep(0.0, 0.9, ambient_occlusion);
            directSkyLightIntensity *= ambient_occlusion * map(abs(lightDirectionDotNormal), 0.0, 1.0, 0.2, 1.0);
        }
    #endif
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
    // apply sky light color
    vec3 directSkyLight = directSkyLightIntensity * skyLightColor;
    // apply shadow
    directSkyLight = mix(directSkyLight, directSkyLight * shadow.rgb, shadow.a);

    // -- ambient sky light
    vec3 ambientSkyLight = faceTweak * ambientSkyLightFactor * skyLightColor * ambientSkyLightIntensity;

    // -- block light
    vec3 blockLightColor = getBlockLightColor(blockLightIntensity, emissivness);
    vec3 blockLight = faceTweak * blockLightColor;

    // -- ambient light
    vec3 ambiantLightColor = light10000K;
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
    vec3 color = albedo * light;
    // -- specular
    if (0.1 < smoothness) {
        float specularFade = map(distanceFromCamera, endShadowDecrease * 0.6, startShadowDecrease * 0.6, 0.0, 1.0);
        vec3 specular = vec3(0.0);

        // subsurface transmission highlight
        #if SUBSURFACE_TYPE == 1
            if (ambient_occlusion > 0.0) {
                specular = specularFade * specularSubsurfaceBRDF(worldSpaceViewDirection, worldSpacelightDirection, albedo);
            }
        #endif

        // specular reflection
        specular += CookTorranceBRDF(normal, worldSpaceViewDirection, worldSpacelightDirection, albedo, smoothness, reflectance);

        // add specular contribution
        color += directSkyLight * specular;
    }
    // -- fresnel
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        if (isTransparent) {
            float fresnel = fresnel(worldSpaceViewDirection, normal, reflectance);
            transparency = max(transparency, fresnel);
        }
    #endif

    return vec4(color, transparency);
}
