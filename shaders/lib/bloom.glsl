vec3 doBloom(vec2 uv, sampler2D texture, float normalizedRange, float resolution, float std, bool isGaussian, bool isFirstPass) {

    // no blur
    if (normalizedRange <= 0.0 || resolution <= 0.0)
        return SRGBtoLinear(texture2D(texture, uv).rgb);

    // prepare loop
    float range = 0.0, stepLength = 0.0;
    prepareBlurLoop(normalizedRange, resolution, isFirstPass, range, stepLength);
    // init sums
    vec3 totalBloom = vec3(0.0);

    const int n = 2;
    const int lodMin = 3;
    const int lodMax = 6;
    for (int lod=lodMin; lod<=lodMax; ++lod) {
        float blurSize = pow(2.0, float(lod)) / n;

        // get noise
        float noise = pseudoRandom(uv + 0.1*lod + frameTimeCounter / 3600.0);
        float theta = noise * 2.0*PI;
        float cosTheta = cos(theta);
        float sinTheta = sin(theta);
        // rotation matrix
        mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

        vec3 bloom = vec3(0.0);
        float totalWeight = 0.0;
        for (int x=-n; x<=n; ++x) {
            vec2 offset = isFirstPass ? vec2(x, 0.0) : vec2(0.0, x);
            offset = offset * blurSize / vec2(viewWidth, viewWidth);
            offset = rotation * offset;

            float weight = 1.0;

            bloom += weight * SRGBtoLinear(texture2DLod(texture, uv + offset, lod).rgb);
            totalWeight += weight;
        }
        float lodFactor = exp(-lod * 0.33);
        totalBloom += lodFactor * bloom / totalWeight;
    }

    totalBloom = clamp(totalBloom / (lodMax - lodMin + 1), 0.0, 1.0);
    return totalBloom;
}
