// hard TAA : soft shadows & anti aliasing, but may add a bit of blur or ghosting
vec3 doTAA(vec2 uv, float depth, vec3 color, sampler2D colorTexture, sampler2D taaColorTexture, 
            out vec3 taaColorData) {

    if (frameTimeCounter > 0.0) {
        // get last uv position of actual fragment
        vec3 playerSpacePosition = screenToPlayer(uv, depth);
        vec3 previousPlayerSpacePosition = playerSpacePosition + cameraPosition - previousCameraPosition;
        vec3 previousScreenSpacePosition = previousPlayerToScreen(previousPlayerSpacePosition);
        vec2 prevUV = previousScreenSpacePosition.xy;

        if (isInRange(prevUV, 0.0, 1.0)) {
            vec3 previousColor = SRGBtoLinear(texture2D(taaColorTexture, prevUV).rgb);

            float blendFactor = 0.9;
            // pixel velocity reject
            vec2 pixelVelocity = (uv - prevUV) * vec2(viewWidth, viewHeight);
            blendFactor *= map(exp(- 2 * length(pixelVelocity)), 0.0, 1.0, 0.7, 1.0);

            // neighborhood clipping
            vec3 minColor = vec3(1.0), maxColor = vec3(0.0);
            for (int i=-1; i<=1; i+=1) {
                for (int j=-1; j<=1; j+=1) {
                    if (i==0 && j==0) continue;
                    vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
                    vec3 neighborColor = SRGBtoLinear(texture2D(colorTexture, uv + offset).rgb);

                    minColor = min(minColor, neighborColor);
                    maxColor = max(maxColor, neighborColor);
                } 
            }
            previousColor = clamp(previousColor, minColor, maxColor);

            // blend
            color = mix(color, previousColor, blendFactor);
        }   
    }

    taaColorData = linearToSRGB(color);
    return color;
}

// soft TAA : only soft shadows, a bit slower
vec3 doTAA(vec2 uv, float depth, vec3 color, sampler2D colorTexture, sampler2D taaColorTexture, sampler2D taaDepthTexture, 
            out vec3 taaColorData, out float taaDepthData) {

    if (frameTimeCounter > 0.0) {
        // get last uv position of actual fragment
        vec3 playerSpacePosition = screenToPlayer(uv, depth);
        vec3 previousPlayerSpacePosition = playerSpacePosition + cameraPosition - previousCameraPosition;
        vec3 previousScreenSpacePosition = previousPlayerToScreen(previousPlayerSpacePosition);
        vec2 prevUV = previousScreenSpacePosition.xy;

        if (isInRange(prevUV, 0.0, 1.0)) {
            vec3 previousColor = SRGBtoLinear(texture2D(taaColorTexture, prevUV).rgb);
            float previousDepth = texture2D(taaDepthTexture, prevUV).r;

            float noise = pseudoRandom(uv + 0.14291 * frameTimeCounter);
            vec3 previousRealPlayerSpacePosition = screenToPlayer(prevUV, previousDepth);
            float dist = abs(length(previousRealPlayerSpacePosition) - length(playerSpacePosition));

            float blendFactor = 0.9;
            // depth reject
            blendFactor *= 1.0 - smoothstep(0.0, 0.1*noise + 1.0, dist);
            // pixel velocity reject
            vec2 pixelVelocity = (uv - prevUV) * vec2(viewWidth, viewHeight);
            blendFactor *= map(exp(- length(pixelVelocity)), 0.0, 1.0, 0.75, 1.0);

            // neighborhood clipping
            vec3 minColor = vec3(1.0), maxColor = vec3(0.0);
            for (int i=-1; i<=1; i+=1) {
                for (int j=-1; j<=1; j+=1) {
                    if (i==0 && j==0) continue;
                    vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
                    vec3 neighborColor = SRGBtoLinear(texture2D(colorTexture, uv + offset).rgb);

                    minColor = min(minColor, neighborColor);
                    maxColor = max(maxColor, neighborColor);
                } 
            }
            previousColor = clamp(previousColor, minColor, maxColor);

            // blend
            color = mix(color, previousColor, blendFactor);
        }   
    }

    taaColorData = linearToSRGB(color);
    taaDepthData = depth;
    return color;
}
