vec4 blur(vec2 uv, sampler2D texture, float range, float samples, float std, bool isGaussian, bool isFirstPass) {

    // no blur
    if (range <= 0.0 || samples < 1)
        return SRGBtoLinear(texture2D(texture, uv));

    float ratio = viewWidth / viewHeight;

    // prepare loop
    float step_length = range / samples;
    vec4 color = vec4(0);
    float count = 0;

    for (float x=-range; x<=range; x+=step_length) {
        vec2 offset = vec2(0,x);
        if (isFirstPass)
            offset = vec2(x/ratio,0);

        vec2 coord = uv + offset;
        coord = clamp(coord, 0, 1);

        // box kernel
        float weight = 1;
        // gaussian kernel
        if (isGaussian) {
            weight = gaussian(x / range, 0, std);
        }

        color += weight * SRGBtoLinear(texture2D(texture, coord));
        count += weight;
    }

    return color / count;
}
