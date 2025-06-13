// end portal texture colors
const vec3[7] endPortalColors = vec3[](
    vec3(0.098, 0.196, 0.255), // dark cyan
    vec3(0.118, 0.235, 0.275), // greenish dark cyan
    vec3(0.1125, 0.294, 0.2295), // dark green
    vec3(0.196, 0.118, 0.392), // dark blue purple
    vec3(0.075, 0.196, 0.153), // dark green
    vec3(0.157, 0.220, 0.333), // dark blue
    vec3(0.15, 0.392, 0.306)  // dark green
);

void getWaterMaterialData(inout float smoothness, inout float reflectance) {
    smoothness = 0.9;
    reflectance = isEyeInWater == 0 
        ? getReflectance(1.0, 1.33)
        : getReflectance(1.33, 1.0);
}

void getSpecificMaterial(sampler2D gtexture, int id, vec3 texture, vec3 tint, inout vec3 albedo, inout float transparency, inout float emissivness, inout float subsurfaceScattering) {

    // end portal & end gates
    #ifdef TERRAIN
        if (isEndPortal(id)) {
            albedo = vec3(0.0);
            vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
            float speed = frameTimeCounter * 0.005;

            screenPos *= 0.75;
            vec3 tint = vec3(0.098, 0.196, 0.255);

            for (int i=0; i<8; ++i) {
                for (int j=0; j<3; ++j) {
                    float theta = j * PI/3.0 + i * PI/8.0;
                    mat2 rotation = rotationMatrix(theta);

                    vec2 uv = mod(rotation * screenPos.xy + speed, 1.0);
                    vec3 portalColor = texture2D(gtexture, uv).rgb * normalize(endPortalColors[(i+j) % 7]) * 0.8;
                    portalColor *= map(1.0 - (float(i) / 8.0), 0.0, 1.0, 0.33, 1.0);
                    albedo += portalColor * length(portalColor);
                }

                screenPos *= 1.4;
            }

            albedo *= tint;
            albedo = mix(albedo * 2.0, tint, length(albedo));
            albedo += tint * 0.08;
            albedo *= 1.5;

            emissivness = getLightness(albedo) < 0.2 ? 0.0 : 1.0;
        }
    #endif

    // particles
    #ifdef PARTICLE

        // all types of glowing particles
        bool isObsidianTears = isEqual(tint, vec3(130.0, 8.0, 227.0) / 255.0, 2.0/255.0);
        bool isBlossom = isEqual(tint, vec3(80.0, 127.0, 56.0) / 255.0, 2.0/255.0);
        bool isRedstone = tint.r > 0.1 && tint.g < 0.2 && tint.b < 0.1;
        bool isEnchanting = isEqual(tint.r, tint.g, 2.0/255.0) && 10.0/255.0 < (tint.b - tint.r) && (tint.b - tint.r) < 30.0/255.0; // also trigger warpped forest particles
        bool isNetherPortal = 0.0 < (tint.b - tint.r) && (tint.b - tint.r) < 30.0/255.0 && 2.0*tint.g < tint.b;
        bool isLava = (albedo.r > 250.0/255.0 && albedo.g > 70.0/255.0 && albedo.b < 70.0/255.0) || tint.r > 250.0/255.0 && tint.g > 70.0/255.0 && tint.b < 70.0/255.0;
        bool isSoulFire = isEqual(texture, vec3(96.0, 245.0, 250.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(1.0, 167.0, 172.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(0.0, 142.0, 146.0) / 255.0, 2.0/255.0);
        bool isCrimsonForest = isEqual(tint, vec3(229.0, 101.0, 127.0) / 255.0, 2.0/255.0);
        bool isGreenGlint = isEqual(texture, vec3(6.0, 229.0, 151.0) / 255.0, 6.0/255.0)
            || isEqual(texture, vec3(4.0, 201.0, 77.0) / 255.0, 6.0/255.0)
            || isEqual(texture, vec3(2.0, 179.0, 43.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(0.0, 150.0, 17.0) / 255.0, 2.0/255.0);
        bool isSculkSoundWave = isEqual(texture, vec3(57.0, 214.0, 224.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(42.0, 227.0, 235.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(14.0, 180.0, 170.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(10.0, 126.0, 129.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(12.0, 81.0, 78.0) / 255.0, 2.0/255.0);

        // emissive 
        if (isNetherPortal || isRedstone || isObsidianTears || isBlossom || isEnchanting || isLava || isSoulFire || isCrimsonForest || isGreenGlint || isSculkSoundWave) {
            subsurfaceScattering = 1.0;
            emissivness = 1.0;

            // saturate some of them
            if ((isNetherPortal && !isObsidianTears) || isRedstone || isBlossom) {
                albedo *= 1.5;
            }
        }

        // all type of transparent particles
        bool isRain = isEqual(texture, vec3(72.0, 106.0, 204.0) / 255.0, 2.0/255.0)
            || isEqual(texture, vec3(23.0, 72.0, 204.0) / 255.0, 6.0/255.0)
            || isEqual(texture, vec3(0.0, 54.0, 204.0) / 255.0, 2.0/255.0);

        // transparent
        if (isRain) {
            transparency *= rainStrength;
            transparency = min(transparency, 0.2);
        }
    #endif

    // weather particles
    #ifdef WEATHER

        // differentiates snow and rain
        bool isSnow = isEqual(min(texture.r, min(texture.g, texture.b)), 1.0, 2.0/255.0);

        float maxTransparency = isSnow ? 0.5 : 0.2;
        transparency *= rainStrength; // weather fade-in/out
        transparency = min(transparency, maxTransparency); // clamp transparency
    #endif
}

void getCustomMaterialData(int id, vec3 normal, vec3 midBlock, vec2 localTextureCoordinate, vec3 texture, vec3 albedo, inout float smoothness, inout float reflectance, inout float emissivness, inout float ambientOcclusion, inout float subsurfaceScattering, inout float porosity) {

    // -- water smoothness & reflectance -- //
    if (isWater(id)) {
        getWaterMaterialData(smoothness, reflectance);
        smoothness -= 0.3 - map(texture.r, 124.0/255.0, 191.0/255.0, 0.0, 0.3);
        reflectance += map(texture.r, 124.0/255.0, 191.0/255.0, 0.0, 0.05);
    }
    else {
        // -- smoothness -- //
        if (isVerySmooth(id)) {
            smoothness = 0.95;
        }
        else if (isSmooth(id)) {
            smoothness = 0.75;
        }
        else if (isSlightlySmooth(id)) {
            smoothness = 0.5;
        }
        else if (isSlightlyRough(id)) {
            smoothness = 0.4;
        }
        else if (isRough(id)) {
            smoothness = 0.2;
        }
        // else is very rough : smoothness = 0.0

        // change smoothness on top of blocks that have grass
        if (hasGrass(id) && normal.y > 0.5) {
            smoothness = 0.45;
        }

        // -- reflectance -- //
        // index of refraction of the actual medium
        float n1 = isEyeInWater > 0 ? 1.33 : 1.0;
        if (hasMetallicReflectance(id)) {
            reflectance = 0.3;
        }
        else if (hasHighReflectance(id)) {
            reflectance = getReflectance(n1, 1.5);
        }
        else if (hasMediumReflectance(id)) {
            reflectance = getReflectance(n1, 1.4);
        }
        else { // default reflectance
            reflectance = getReflectance(n1, 1.3);
        }
    }

    // -- emissivness -- //
    if (isFullyEmissive(id)) {
        emissivness = 1.0;
    }
    else if (isSemiEmissive(id)) {
        emissivness = max(getLightness(albedo), max(albedo.r, max(albedo.g, albedo.b)));
        emissivness = smoothstep(0.25, 0.75, emissivness);
    }
    else if (isLitRedstone(id)) {
        if (albedo.r > 90.0/255.0 && (albedo.r - max(albedo.g, albedo.b) > 64.0/255.0 || albedo.r > 245.0/255.0) && (albedo.b < 5.0/255.0 || abs(albedo.b - albedo.g) < 5.0/255.0)) {
            emissivness = 1.0;
        }
    }
    #if EMISSIVE_ORES > 0
        else if (isOre(id)) {
            bool isQuartz = isEqual(albedo, vec3(234.0, 229.0, 222.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(212.0, 202.0, 186.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(182.0, 164.0, 142.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(111.0, 88.0, 67.0) / 255.0, 2.0/255.0);
            bool isCoal = isEqual(albedo, vec3(10.0, 10.0, 10.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(31.0, 31.0, 31.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(37.0, 37.0, 37.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(42.0, 42.0, 42.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(46.0, 46.0, 46.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(54.0, 54.0, 54.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(58.0, 60.0, 55.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(73.0, 75.0, 63.0) / 255.0, 2.0/255.0);
            bool isIron = isEqual(albedo, vec3(226.0, 192.0, 170.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(215.0, 175.0, 147.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(175.0, 142.0, 119.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(136.0, 116.0, 85.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(118.0, 103.0, 79.0) / 255.0, 2.0/255.0);
            bool isCopper = isEqual(albedo, vec3(243.0, 130.0, 105.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(224.0, 115.0, 77.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(193.0, 103.0, 70.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(129.0, 128.0, 89.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(58.0, 104.0, 90.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(57.0, 118.0, 99.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(89.0, 149.0, 129.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(80.0, 186.0, 152.0) / 255.0, 2.0/255.0);
            bool isGold = isEqual(albedo, vec3(255.0, 255.0, 181.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(253.0, 237.0, 74.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(235.0, 157.0, 13.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(156.0, 112.0, 32.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(156.0, 99.0, 33.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(248.0, 175.0, 42.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(199.0, 100.0, 28.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(179.0, 67.0, 23.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(218.0, 145.0, 16.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(126.0, 69.0, 13.0) / 255.0, 2.0/255.0)
                || isEqual(albedo, vec3(69.0, 27.0, 3.0) / 255.0, 2.0/255.0);
            bool isRedstone = isEqual(albedo, vec3(151.0, 4.0, 5.0) / 255.0, 4.0/255.0)
                || isEqual(albedo, vec3(197.0, 6.0, 5.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(247.0, 28.0, 28.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(255.0, 0.0, 0.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(255.0, 94.0, 94.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(255.0, 137.0, 137.0) / 255.0, 8.0/255.0);
            bool isEmerald = isEqual(albedo, vec3(216.0, 255.0, 235.0) / 255.0, 4.0/255.0)
                || isEqual(albedo, vec3(64.0, 243.0, 132.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(25.0, 197.0, 68.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(27.0, 152.0, 42.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(2.0, 123.0, 23.0) / 255.0, 8.0/255.0);
            bool isLapis = isEqual(albedo, vec3(104.0, 149.0, 244.0) / 255.0, 4.0/255.0)
                || isEqual(albedo, vec3(68.0, 111.0, 220.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(23.0, 85.0, 189.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(16.0, 52.0, 189.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(22.0, 68.0, 141.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(16.0, 52.0, 156.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(16.0, 68.0, 172.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(32.0, 89.0, 139.0) / 255.0, 8.0/255.0);
            bool isDiamond = isEqual(albedo, vec3(213.0, 255.0, 246.0) / 255.0, 4.0/255.0)
                || isEqual(albedo, vec3(119.0, 231.0, 210.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(29.0, 208.0, 214.0) / 255.0, 8.0/255.0)
                || isEqual(albedo, vec3(36.0, 150.0, 152.0) / 255.0, 8.0/255.0);

            if (isQuartz || isCoal || isIron || isCopper || isGold || isRedstone || isEmerald || isLapis || isDiamond) {
                emissivness = 1.0;
            }
        }
    #endif

    // -- ambient occlusion -- //
    #if AMBIENT_OCCLUSION_TYPE > 0
        if (hasAmbientOcclusion(id)) {
            // calculate AO via midBlock
            if (hasFixedPosition(id)) {
                vec3 objectSpacePosition = midBlockToRoot_ao(id, midBlock);
                if (objectSpacePosition.y > 0.0) {
                    ambientOcclusion = distance(0.0, objectSpacePosition.y);
                    ambientOcclusion = min(ambientOcclusion, 1.0);
                }
            }
            // calculate AO via UV
            else {
                vec2 objectSpacePosition = offsetUV(id, localTextureCoordinate);
                // vertically from root to top
                if (hasVerticalAmbientOcclusion(id)) {
                    ambientOcclusion = distance(0.0, objectSpacePosition.y);
                    ambientOcclusion = min(ambientOcclusion, 1.0);
                }
                // horizontally from center to extremity
                else if (hasHorizontalAmbientOcclusion(id)) {
                    ambientOcclusion = distance(0.0, objectSpacePosition.x);
                    ambientOcclusion = min(2.0 * ambientOcclusion, 1.0);
                }
                // vertically & horizontally from root to extremities
                else {
                    ambientOcclusion = distance(vec2(0.0), objectSpacePosition);
                }
            }
        }
    #endif

    // -- subsurfaceScattering -- //
    #if SUBSURFACE_TYPE > 0
        if (hasSubsurface(id)) {
            subsurfaceScattering = 1.0;
        }
    #endif

    // -- porosity -- //
    #if POROSITY_TYPE > 0
        if (hasHighPorosity(id)) {
            porosity = 0.6;
        }
        else if (hasLowPorosity(id)) {
            porosity = 0.3;
        }
    #endif
}

// handle labPBR format
void getPBRMaterialData(sampler2D normals, sampler2D specular, vec2 textureCoordinate, inout float smoothness, inout float reflectance, inout float emissivness, inout float ambientOcclusion, inout float subsurfaceScattering, inout float porosity) {

    #if PBR_TYPE > 0 && !defined PARTICLE
        vec4 normalMapData = texture2D(normals, textureCoordinate);
        vec4 specularMapData = texture2D(specular, textureCoordinate);

        if (length(normalMapData) > 0.0) {
            // -- ambient occlusion -- //
            ambientOcclusion = normalMapData.z;
        }

        if (length(specularMapData) > 0.0) {
            // -- smoothness -- //
            smoothness = specularMapData.r;

            // -- reflectance -- //
            reflectance = specularMapData.g;
            if (reflectance > 229.0/255.0) {
                reflectance = 0.5;
            }

            // -- subsurface scattering -- //
            if (specularMapData.b > 64.0/255.0) {
                subsurfaceScattering = map(specularMapData.b, 65.0/255.0, 255.0/255.0, 0.0, 1.0);
            }
            // -- porosity -- //
            #if PBR_POROSITY > 0
                else {
                    porosity = map(specularMapData.b, 0.0/255.0, 64.0/255.0, 0.0, 1.0);
                }
            #endif

            // -- emissivness -- //
            emissivness = specularMapData.a < 1.0 ? specularMapData.a : 0.0;
            // fix issues caused by mipmaps
            float emissivnessL0 = texture2DLod(specular, textureCoordinate, 0).a;
            emissivnessL0 = emissivnessL0 < 1.0 ? emissivnessL0 : 0.0;
            emissivness = min(emissivness, emissivnessL0);
        }
    #endif
}

void getDHMaterialData(int id, inout vec3 albedo, out float smoothness, out float reflectance, out float emissivness) {
    smoothness = 0.0;
    reflectance = 0.0;
    emissivness = 0.0;

    float n1 = isEyeInWater == 1 ? 1.33 : 1.0;

    // water
    if (id == DH_BLOCK_WATER) {
        smoothness = 0.9;
        float n2 = isEyeInWater == 0 ? 1.33 : 1.0;
        reflectance = getReflectance(n1, n2);
    }
    // metal
    else if (id == DH_BLOCK_METAL) {
        smoothness = 0.75;
        reflectance = getReflectance(n1, 3.0);
    }
    // leaves
    else if (id == DH_BLOCK_LEAVES) {
        smoothness = 0.25;
        reflectance = getReflectance(n1, 2.5);
    }
    // emissive
    else if (id == DH_BLOCK_ILLUMINATED) {
        emissivness = 1.0;
        albedo *= 1.5;
    }
}
