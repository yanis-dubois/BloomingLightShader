vec3 depthOfField(vec2 uv, sampler2D colorTexture, sampler2D DOFTexture, float range, float resolution, float std, bool isGaussian, bool isFirstPass, out vec4 DOFdata) {

    // color data
    vec3 color = SRGBtoLinear(texture2D(colorTexture, uv).rgb);
    color = inverseToneMap(color);
    // retrieve depth of field data
    DOFdata = texture2D(DOFTexture, uv);
    bool isNearPlane = DOFdata.r > 0.1 ? true : false;
    bool isFarPlane = DOFdata.g > 0.1 ? true : false;
    bool isInFocus = !isNearPlane && !isFarPlane;

    // prepare loop
    float ratio = viewWidth / viewHeight;
    float samples = isFirstPass ? viewWidth * range / ratio : viewHeight * range;
    float stepLength = range / (resolution * samples);
    vec3 nearDOF = vec3(0.0), farDOF = vec3(0.0);
    float nearTotalWeight = 0.0;
    float farTotalWeight = 0.0;

    // loop
    for (float x=-range; x<=range; x+=stepLength) {
        vec2 offset = isFirstPass ? vec2(x / ratio, 0.0) : vec2(0.0, x);
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
        bool sampleIsFarPlane = sampleDOFdata.g > 0.1 ? true : false;
        bool sampleIsInFocus = !sampleIsNearPlane && !sampleIsFarPlane;

        vec3 col = SRGBtoLinear(texture2D(colorTexture, coord).rgb);
        // inverse karis average
        weight *= 1 + getLightness(col);

        // far plane mix only with far & near planes
        if (isFarPlane && sampleIsFarPlane) {
            farDOF += weight * inverseToneMap(col);
            farTotalWeight += weight;
        }
        // update blur factor
        if (sampleIsNearPlane) {
            if (sampleDOFdata.r > DOFdata.r) {
                DOFdata.r = sampleDOFdata.r;
                DOFdata.g = 0.0;
            }
        }

        // near plane mix with all plane
        nearDOF += weight * inverseToneMap(col);
        nearTotalWeight += weight;
    }

    // normalize values
    nearDOF /= nearTotalWeight;
    if (farTotalWeight > 0.0) farDOF /= farTotalWeight;

    // choose values depending on planes
    vec3 DOF = color;
    DOF = mix(DOF, farDOF, DOFdata.g);
    DOF = mix(DOF, nearDOF, DOFdata.r);

    DOF = clamp(toneMap(DOF), 0.0, 1.0);

    return DOF;
}
