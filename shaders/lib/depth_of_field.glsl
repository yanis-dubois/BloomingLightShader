vec3 depthOfField(vec2 uv, sampler2D colorTexture, sampler2D DOFTexture, float range, float samples, float std, bool isGaussian, bool isFirstPass, out vec4 DOFdata) {

    // color data
    vec3 color = SRGBtoLinear(texture2D(colorTexture, uv).rgb);
    // retrieve depth of field data
    DOFdata = texture2D(DOFTexture, uv);
    bool isNearPlane = DOFdata.r > 0.1 ? true : false;
    bool isFarPlane = !isNearPlane && DOFdata.g > 0.1 ? true : false;
    bool isInFocus = !isNearPlane && !isFarPlane;
    float blurFactor = DOFdata.b;

    // prepare loop
    float ratio = viewWidth / viewHeight;
    float stepLength = range / samples;
    vec3 nearDOF = vec3(0.0), farDOF = vec3(0.0);
    float nearTotalWeight = 0.0;
    float farTotalWeight = 0.0;

    // loop
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

        // sample
        vec4 sampleDOFdata = texture2D(DOFTexture, coord);
        bool sampleIsNearPlane = sampleDOFdata.r > 0.1 ? true : false;
        bool sampleIsFarPlane = !sampleIsNearPlane && sampleDOFdata.g > 0.1 ? true : false;
        bool sampleIsInFocus = !sampleIsNearPlane && !sampleIsFarPlane;
        float sampleBlurFactor = sampleDOFdata.b;

        // far plane mix only with far & near planes
        if (isFarPlane && (sampleIsFarPlane || sampleIsNearPlane)) {
            weight *= sampleBlurFactor;
            farDOF += weight * SRGBtoLinear(texture2D(colorTexture, coord).rgb);
            farTotalWeight += weight;
        }
        // update blur factor
        if ((isInFocus && sampleIsNearPlane)) {
            blurFactor = max(blurFactor, sampleBlurFactor);
        }
        // ...
        if (sampleIsNearPlane) {
            if (sampleDOFdata.r > DOFdata.r) {
                DOFdata.r = sampleDOFdata.r;
                DOFdata.g = 0.0;
                DOFdata.b = sampleBlurFactor;
            }
        }

        // near plane mix with all plane
        nearDOF += weight * SRGBtoLinear(texture2D(colorTexture, coord).rgb);
        nearTotalWeight += weight;
    }

    // normalize values
    nearDOF /= nearTotalWeight;
    if (farTotalWeight > 0.0) farDOF /= farTotalWeight;

    // choose values depending on planes
    vec3 DOF = vec3(0.0);
    if (isFarPlane) {
        DOF = mix(color, farDOF, blurFactor);
    }
    else {
        DOF = mix(color, nearDOF, blurFactor);
    }

    return DOF;
}
