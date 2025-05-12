vec3 doBlur(vec2 uv, sampler2D texture, float normalizedRange, float resolution, float std, bool isGaussian, int ditheringType, bool isFirstPass) {

    // no blur
    if (normalizedRange <= 0.0 || resolution <= 0.0)
        return SRGBtoLinear(texture2D(texture, uv).rgb);

    // prepare loop
    float range = 0.0, stepLength = 0.0;
    prepareBlurLoop(normalizedRange, resolution, isFirstPass, range, stepLength);

    // init sums
    vec3 color = vec3(0.0);
    float totalWeight = 0.0;

    // random rotation matrix
    float dither = dithering(uv + 0.25, ditheringType);
    mat2 rotation = randomRotationMatrix(dither);

    for (float x=-range; x<=range; x+=stepLength) {
        vec2 offset = isFirstPass ? vec2(x, 0.0) : vec2(0.0, x);
        offset = rotation * offset;

        vec2 coord = uv + offset;
        coord = clamp(coord, 0.0, 1.0);

        // box kernel
        float weight = 1.0;
        // gaussian kernel
        if (isGaussian) {
            weight  = gaussian(x / range, std);
        }

        color += weight * SRGBtoLinear(texture2D(texture, coord).rgb);
        totalWeight += weight;
    }

    return color / totalWeight;
}
