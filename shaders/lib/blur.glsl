vec4 blur(vec2 uv, sampler2D texture, float range, float resolution, bool isGaussian, bool isFirstPass) {

    // no blur
    if (range <= 0.0 || resolution <= 0.0)
        return SRGBtoLinear(texture2D(texture, uv));

    // prepare loop
    float samples = range * resolution;
    float step_length = range / samples;
    vec4 color = vec4(0);
    float count = 0;

    for (float x=-range; x<=range; x+=step_length) {
        vec2 offset = vec2(0,x);
        if (isFirstPass)
            offset = vec2(x,0);

        vec2 coord = uv + texelToScreen(offset);

        // box kernel
        float weight = 1;
        // gaussian kernel
        if (isGaussian) {
            weight = gaussian(x / range, 0, BLOOM_STD);
        }

        color += weight * SRGBtoLinear(texture2D(texture, coord));
        count += weight;
    }

    return color / count;
}
