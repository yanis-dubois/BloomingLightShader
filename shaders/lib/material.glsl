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

void getMaterialData(sampler2D gtexture, int id, vec3 normal, vec3 midBlock, inout vec3 albedo, out float smoothness, out float reflectance, out float emissivness, out float ambient_occlusion) {
    smoothness = 0.0;
    reflectance = 1.0;
    emissivness = 0.0;
    ambient_occlusion = 0.0;

    float n1 = isEyeInWater == 1 ? 1.33 : 1.0;

    // -- smoothness -- //
    // water
    if (id == 20000) {
        smoothness = 0.9;
        float n2 = isEyeInWater == 0 ? 1.33 : 1.0;
        reflectance = getReflectance(n1, n2);
    }
    // glass 
    else if (id == 20010 || id == 20011 || id == 20012 || id == 20013 || id == 20014) {
        smoothness = 0.95;
        reflectance = getReflectance(n1, 1.5);
    }
    // metal
    else if (id == 20020) {
        smoothness = 0.75;
        reflectance = getReflectance(n1, 3.0);
    }
    // polished
    else if (id == 20030 || id == 20031) {
        smoothness = 0.6;
        reflectance = getReflectance(n1, 1.4);
    }
    // specular
    else if (id == 20040 || id == 20041) {
        // grass block
        if (normal.y > 0.5) {
            if (id == 20040) {
                smoothness = 0.4;
                reflectance = getReflectance(n1, 1.3);
            }
            else if (id == 20041) {
                smoothness = 0.2;
                reflectance = getReflectance(n1, 1.3);
            }
        }
    }
    // rough
    else if (id == 20050) {
        smoothness = 0.2;
        reflectance = getReflectance(n1, 1);
    }
    // emmissive and smooth
    else if (id == 30030 || id == 30040) {
        smoothness = 0.95;
        reflectance = getReflectance(n1, 1.5);
    }

    // -- emmissive -- //
    if (id >= 30000) {
        if (id < 30040) {
            emissivness = getLightness(albedo);
        }
        else if (id == 30040) {
            emissivness = 1;
            albedo *= 1.5;
        }
        // end portal & end gates
        #ifdef TERRAIN
            else if (id == 31000) {
                albedo = vec3(0.0);
                vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
                float speed = frameTimeCounter * 0.005;

                screenPos *= 0.75;
                vec3 tint = vec3(0.098, 0.196, 0.255);

                for (int i=0; i<8; ++i) {
                    for (int j=0; j<3; ++j) {
                        float angle = j * PI/3.0 + i * PI/8.0;
                        float Cos = cos(angle);
                        float Sin = sin(angle);
                        mat2 rotation = mat2(Cos, Sin, -Sin, Cos);

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
    }

    // -- subsurface & ao -- //
    if (10000 <= id && id < 20000) {
        smoothness = 0.25; // 0.45
        reflectance = getReflectance(n1, 2.5);

        // leaves
        if (hasNoAmbiantOcclusion(id)) {
            ambient_occlusion = 1;
        }
        // flowers
        else if (isThin(id)) {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(0, objectSpacePosition.y);
            ambient_occlusion = min(ambient_occlusion, 1);
        }
        // sugar cane
        else if (isColumnSubsurface(id)) {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(vec2(0), objectSpacePosition.xz);
            ambient_occlusion = min(ambient_occlusion*5, 1);
        }
        // other foliage
        else {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(vec3(0), objectSpacePosition);
        }
    }

    // -- porosity -- //
    // if (20030 < id && id < 30000) {
    //     float porosityFactor = 0.6;
    //     smoothness = max(smoothness, mix(smoothness, 0.9 * porosityFactor, rainStrength));
    //     reflectance = max(reflectance, mix(reflectance, getReflectance(1.0, 1.33) * porosityFactor, rainStrength));
    // }
}
