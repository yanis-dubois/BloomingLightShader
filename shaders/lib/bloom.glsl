vec4 doBloom(vec2 uv, sampler2D texture, bool isFirstPass) {

    // init sums
    vec3 totalBloom = vec3(0.0);
    float totalSunBloom = 0.0;

    // loop over multiple LODs
    const int n = BLOOM_MODERN_SAMPLES;
    const int lodMin = 3;
    const int lodMax = 7;
    for (int lod=lodMin; lod<=lodMax; ++lod) {
        float blurSize = pow(2.0, float(lod + BLOOM_MODERN_RANGE)) / n;

        // random rotation matrix
        float dither = dithering(uv + 0.1*lod, BLOOM_DITHERING_TYPE);
        mat2 rotation = randomRotationMatrix(dither);

        // loop over pixel neighbors
        vec3 bloom = vec3(0.0);
        float sunBloom = 0.0;
        float totalWeight = 0.0;
        float totalSunWeight = 0.0;
        for (int x=-n; x<=n; ++x) {
            vec2 offset = isFirstPass ? vec2(x, 0.0) : vec2(0.0, x);
            offset = offset * blurSize / vec2(viewWidth, viewHeight);
            offset = rotation * offset;

            float weight = 1.0;

            vec4 bloomData = texture2DLod(texture, uv + offset, lod);
            // don't use last layer for classic bloom
            if (lod < lodMax) {
                bloom += weight * SRGBtoLinear(bloomData.rgb);
                totalWeight += weight;
            }
            // don't use first layer for sun bloom
            if (lod > lodMin) {
                sunBloom += weight * bloomData.a;
                totalSunWeight += weight;
            }
        }

        // don't use last layer for classic bloom
        if (lod < lodMax) {
            float lodFactor = exp(-lod * 0.33);
            totalBloom += lodFactor * bloom / totalWeight;
        }
        // don't use first layer for sun bloom
        if (lod > lodMin) {
            totalSunBloom += sunBloom / totalSunWeight;
        }
    }

    int nbLayer = lodMax - lodMin;
    totalBloom = clamp(totalBloom / (nbLayer), 0.0, 1.0);
    totalSunBloom = clamp(totalSunBloom / (nbLayer), 0.0, 1.0);
    return vec4(totalBloom, totalSunBloom);
}
