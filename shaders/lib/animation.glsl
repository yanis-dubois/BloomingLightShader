#include "/ext/glsl-noise/simplex/3d.glsl"
#include "/ext/glsl-noise/simplex/4d.glsl"

float getNoise(vec3 seed, float amplitude) {
    float noise = snoise_3D(seed);
    // squared noise for calm moment
    noise *= noise;

    return amplitude * noise;
}

vec2 doWaterRefraction(float time, vec2 uv, vec3 eyeSpaceDirection) {
    float amplitude = 0.005;
    float speed = time * 0.15;
    vec3 seed = vec3(eyeSpaceDirection * 3.0) + speed;

    uv.x = amplitude * snoise_3D(seed);
    uv.y = amplitude * snoise_3D(seed + 1.0);
    return uv;
}

// used during shadow rendering to simulate caustic
float doLightAnimation(int id, float time, vec3 worldSpacePosition) {
    float amplitude = 0.0;
    if (animatedLight_isHigh(id)) amplitude = 0.8;
    else if (animatedLight_isMedium(id)) amplitude = 0.5;
    else if (animatedLight_isLow(id)) amplitude = 0.2;
    
    float speed = time * 0.25;
    vec4 seed = vec4(- worldSpacePosition.y * 0.5, worldSpacePosition.xz * 0.125, 0.0) + speed;
    float noise = snoise_4D(seed);

    return amplitude * noise;
}

// used during shadow rendering to simulate caustic
float doShadowWaterAnimation(float time, vec3 worldSpacePosition) {
    float speed = time * 0.15;
    vec3 seed = vec3(worldSpacePosition.xz * 0.66, speed) + speed;

    float n1 = snoise_3D(seed);
    float n2 = snoise_3D(seed * 1.5 + 0.12);
    float n3 = snoise_3D(seed * 2.0 + 0.141);

    n1 = 1.0 - abs(n1);
    n1 = smoothstep(0.0, 0.9, n1);
    n1 = pow(n1, 16.0);

    n2 = n2 * 0.5 + 0.5;

    n3 = n3 * 0.5 + 0.5;
    n3 = pow(n3, 1.5);

    n1 = mix(n2, n1, n3 * 0.75);
    n1 = pow(n1, 3.0);

    return n1;
}

vec3 doWaterAnimation(float time, vec3 worldSpacePosition, vec3 midBlock) {
    float amplitude = 1.0 / 32.0;
    float speed = time * 0.25;
    vec3 seed = vec3(worldSpacePosition.xz/20.0, 0.0) + speed;
    
    worldSpacePosition.y += amplitude * snoise_3D(seed);
    return worldSpacePosition;
}

vec3 doLeafAnimation(int id, float time, vec3 worldSpacePosition) {
    float amplitude = isVines(id) ? 1.0 / 16.0 : 1.0 / 8.0;
    float speed = time * 0.2;
    vec3 seed = vec3(worldSpacePosition.xz/20.0, worldSpacePosition.y/50.0) + speed;

    worldSpacePosition.x += getNoise(seed, amplitude);
    worldSpacePosition.y += getNoise(seed+1.0, amplitude);
    worldSpacePosition.z += getNoise(seed+2.0, amplitude);
    return worldSpacePosition;
}

// type : 0=not_rooted; 1=ground_rooted; 2=ceiling_rooted; 3=tall_ground_rooted_lower; 4=tall_ground_rooted_upper
vec3 doGrassAnimation(float time, vec3 worldSpacePosition, vec3 midBlock, int id) {
    float amplitude = 1.0 / 4.0;
    float speed = time * 0.2;
    vec3 seed = vec3(worldSpacePosition.xz/20.0, worldSpacePosition.y/50.0) + speed;

    // attuenuate amplitude if rooted
    if (isRooted(id)) {
        vec3 rootOrigin = midBlockToRoot(id, midBlock);
        amplitude *= rootOrigin.y;
    }
    
    worldSpacePosition.x += getNoise(seed, amplitude);
    worldSpacePosition.z += getNoise(seed+2.0, amplitude);
    return worldSpacePosition;
}

vec3 doAnimation(int id, float time, vec3 worldSpacePosition, vec3 midBlock) {
    midBlock /= 64.0; // from [32;-32] to [0.5;-0.5] 
    midBlock.y = -1.0 * midBlock.y + 0.5; // from [0.5;-0.5] to [0;1]

    if (isLiquid(id))
        return doWaterAnimation(time, worldSpacePosition, midBlock);
    if (isFoliage(id))
        return doLeafAnimation(id, time, worldSpacePosition);
    if (isUnderGrowth(id))
        return doGrassAnimation(time, worldSpacePosition, midBlock, id);
    
    return worldSpacePosition;
}
