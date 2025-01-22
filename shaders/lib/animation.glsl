#include "/ext/glsl-noise/simplex/3d.glsl"

float getNoise(vec3 seed, float amplitude, float speed) {
    float noise = snoise(seed + speed);
    // squared noise for calm moment
    noise *= noise;

    return amplitude * noise;
}

// used during shadow rendering to simulate caustic
float doShadowWaterAnimation(float time, vec3 worldSpacePosition) {
    float amplitude = 0.33;
    float speed = time * 0.15;
    vec3 seed = vec3(worldSpacePosition.xz * 0.5, speed);
    
    return amplitude * snoise(seed + speed);
}

vec3 doWaterAnimation(float time, vec3 worldSpacePosition) {
    vec3 seed = vec3(worldSpacePosition.xz/20.0, 0);
    float amplitude = 1.0/32.0;
    float speed = time * 0.25;
    
    worldSpacePosition.y += amplitude * snoise(seed + speed);
    return worldSpacePosition;
}

vec3 doLeafAnimation(float time, vec3 worldSpacePosition) {
    vec3 seed = vec3(worldSpacePosition.xz/20.0, worldSpacePosition.y/50.0);
    float amplitude = 1.0 / 8.0;
    float speed = time * 0.2;

    worldSpacePosition.x += getNoise(seed, amplitude, speed);
    worldSpacePosition.y += getNoise(seed+1, amplitude, speed);
    worldSpacePosition.z += getNoise(seed+2, amplitude, speed);
    return worldSpacePosition;
}

// type : 0=not_rooted; 1=ground_rooted; 2=ceiling_rooted; 3=tall_ground_rooted_lower; 4=tall_ground_rooted_upper
vec3 doGrassAnimation(float time, vec3 worldSpacePosition, vec3 midBlock, int id) {
    vec3 seed = vec3(worldSpacePosition.xz/20.0, worldSpacePosition.y/50.0);
    float amplitude = 1.0 / 4.0;
    float speed = time * 0.2;

    // attuenuate amplitude if rooted
    if (isRooted(id)) {
        vec3 rootOrigin = midBlockToRoot(id, midBlock);
        amplitude *= rootOrigin.y;
    }
    
    worldSpacePosition.x += getNoise(seed, amplitude, speed);
    worldSpacePosition.z += getNoise(seed+2, amplitude, speed);
    return worldSpacePosition;
}

vec3 doAnimation(int id, float time, vec3 worldSpacePosition, vec3 midBlock) {
    if (isLiquid(id))
        return doWaterAnimation(time, worldSpacePosition);
    if (isFoliage(id))
        return doLeafAnimation(time, worldSpacePosition);
    if (isUnderGrowth(id))
        return doGrassAnimation(time, worldSpacePosition, midBlock, id);
    
    return worldSpacePosition;
}
