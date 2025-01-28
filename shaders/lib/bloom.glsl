vec4 bloom(vec2 uv, sampler2D bloomTexture, vec4 bloomData) {

    // no bloom
    #if BLOOM_TYPE == 0
        return vec4(0);

    // only lightness increase
    #elif float(BLOOM_RANGE) <= 0.0 || float(BLOOM_RESOLTUION) <= 0.0
        return SRGBtoLinear(texture2D(bloomTexture, uv));

    // avoid first pass for bloom type that don't require it
    #elif BLOOM_TYPE == 3
        return bloomData * 1.5;

    // bloom
    #else

        // prepare loop
        float range = BLOOM_RANGE;
        float samples = range * BLOOM_RESOLTUION;
        float step_length = range / samples;
        vec4 color = vec4(0);
        float count = 0;

        // stocastic
        #if BLOOM_TYPE == 1
            for (float i=0; i<samples; ++i) {
                // random offset by sampling disk area
                vec2 seed = uv + i + (frameTimeCounter / 60);
                vec2 offset = sampleDiskArea(seed);
                vec2 coord = uv + range * texelToScreen(offset);

                // box
                #if BLOOM_KERNEL == 0
                    float weight = 1;
                // gaussian
                #elif BLOOM_KERNEL == 1
                    float weight = gaussian(offset.x, offset.y, 0, BLOOM_STD);
                #endif

                color += weight * SRGBtoLinear(texture2D(bloomTexture, coord));
                count += weight;
            }

        // classic
        #elif BLOOM_TYPE == 2
            for (float x=-range; x<=range; x+=step_length) {
                for (float y=-range; y<=range; y+=step_length) {
                    vec2 offset = vec2(x,y);
                    vec2 coord = uv + texelToScreen(offset);

                    // box
                    #if BLOOM_KERNEL == 0
                        float weight = 1;
                    // gaussian
                    #elif BLOOM_KERNEL == 1
                        float weight = gaussian(offset.x / range, offset.y / range, 0, BLOOM_STD);
                    #endif

                    color += weight * SRGBtoLinear(texture2D(bloomTexture, coord));
                    count += weight;
                }
            }
        #endif

        return color / count + SRGBtoLinear(texture2D(bloomTexture, uv)) * 0.75;
    #endif
}
