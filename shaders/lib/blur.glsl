vec4 blur(vec2 uv, sampler2D texture, float range, float resolution, float std, bool isGaussian, bool isFirstPass) {

    // no blur
    if (range <= 0.0 || resolution <= 0.0)
        return SRGBtoLinear(texture2D(texture, uv));

    // prepare loop
    float ratio = viewWidth / viewHeight;
    float samples = isFirstPass ? viewWidth * range / ratio : viewHeight * range;
    float stepLength = range / (resolution * samples);
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for (float x=-range; x<=range; x+=stepLength) {
        vec2 offset = vec2(0.0, x);
        if (isFirstPass)
            offset = vec2(x / ratio, 0.0);

        vec2 coord = uv + offset;
        coord = clamp(coord, 0.0, 1.0);

        // box kernel
        float weight = 1.0;
        // gaussian kernel
        if (isGaussian) {
            weight = gaussian(x / range, std);
        }

        color += weight * SRGBtoLinear(texture2D(texture, coord));
        totalWeight += weight;
    }

    return color / totalWeight;
}
