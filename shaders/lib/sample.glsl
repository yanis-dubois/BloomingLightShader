float hash(vec2 uv, float seed) {
    // Combine UV coordinates with the seed
    vec3 p3 = fract(vec3(uv.xyx) * seed);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

// return a random sample in tangent space
vec3 getSample(vec2 uv, float seed) {
    //vec3 zetas = getNoise(uv);
    vec3 zetas = vec3(hash(uv, seed), hash(uv, seed+11.032), hash(uv, seed+402.49174));
    float theta = acos(sqrt(zetas.x));
    float phi = 2 * PI * zetas.y;
    float len = (zetas.z+0.0001) * 0.5 + 0.5;
    return len * vec3(cos(phi)*sin(theta), sin(phi)*sin(theta), cos(theta));
}

// TODO: be sure to normalize sample vec par rapport à l'espace view
float SSAO(vec2 uv, float depth, mat3 TBN) {
    // handle SSAO_SAMPLES<1 by skipping SSAO
    if (SSAO_SAMPLES<1)
        return 1;

    vec3 viewSpacePosition = screenToView(uv, depth);

    float occlusion = 0;
    float weigthts = 0;
    for (int i=0; i<SSAO_SAMPLES; ++i) {
        vec3 sampleTangentSpace = getSample(uv, i);
        vec3 sampleViewSpace = tangentToView(sampleTangentSpace, TBN);

        // offset and scale
        sampleViewSpace = sampleViewSpace * SSAO_RADIUS + viewSpacePosition;

        // convert from view to screen space
        vec3 sampleUV = viewToScreen(sampleViewSpace);

        // test if occluded
        float sampleDepth = texture2D(depthtex0, sampleUV.xy).r;
        if (sampleDepth + SSAO_BIAS > depth) {
            float weight = length(sampleTangentSpace);
            weigthts += weight;
            occlusion += mix(0, 1, weight/SSAO_RADIUS); // atenuate depending on sample radius
        }
    }
    if (weigthts > 0) {
        occlusion /= weigthts;
    }

    return occlusion;
}