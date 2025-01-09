#include "/ext/glsl-noise/simplex/3d.glsl"

float getNoise(vec3 seed, float amplitude, float speed) {
    float noise = snoise(seed + speed);
    // squared noise for calm moment
    noise *= sign(noise) * noise;

    return amplitude * noise;
}

vec3 doWaterAnimation(float worldTime, vec3 worldSpacePosition) {
    vec3 seed = vec3(worldSpacePosition.xz/20.0, 0);
    float amplitude = 1.0/32.0;
    float speed = worldTime;
    
    worldSpacePosition.y += amplitude * snoise(seed + speed);
    return worldSpacePosition;
}

vec3 doLeafAnimation(float worldTime, vec3 worldSpacePosition) {
    vec3 seed = vec3(worldSpacePosition.xz/20.0, worldSpacePosition.y/50.0);
    float amplitude = 1.0 / 8.0;
    float speed = worldTime / 2.0; 
    speed*= 1.25;

    worldSpacePosition.x += getNoise(seed, amplitude, speed);
    worldSpacePosition.y += getNoise(seed+1, amplitude, speed);
    worldSpacePosition.z += getNoise(seed+2, amplitude, speed);
    return worldSpacePosition;
}

// type : 0=not_rooted; 1=ground_rooted; 2=ceiling_rooted; 3=tall_ground_rooted_lower; 4=tall_ground_rooted_upper
vec3 doGrassAnimation(float worldTime, vec3 worldSpacePosition, vec3 midBlock, int type) {
    vec3 seed = vec3(worldSpacePosition.xz/20.0, worldSpacePosition.y/50.0);
    float amplitude = 1.0 / 4.0;
    float speed = worldTime / 2.0; 
    speed*= 1.25;

    // attuenuate amplitude if rooted
    if (type > 0) {
        midBlock /= 64.0;
        midBlock.y = -1 * midBlock.y + 0.5;
        if (type == 2) midBlock.y = 1 - midBlock.y;
        else if (type == 3) midBlock.y *= 0.5;
        else if (type == 4) midBlock.y = midBlock.y * 0.5 + 0.5;

        amplitude *= midBlock.y;
    }
    
    worldSpacePosition.x += getNoise(seed, amplitude, speed);
    worldSpacePosition.z += getNoise(seed+2, amplitude, speed);
    return worldSpacePosition;
}

vec3 doAnimation(int id, float worldTime, vec3 worldSpacePosition, vec3 midBlock) {
    // from [0;1] to [0;1000]
    worldTime *= 1000;

    if (id == 20000)
        return doWaterAnimation(worldTime, worldSpacePosition);
    if (id == 10030 || id == 10031)
        return doLeafAnimation(worldTime, worldSpacePosition);
    if (id == 10021)
        return doGrassAnimation(worldTime, worldSpacePosition, midBlock, 0);
    if (id == 10000 || id == 10001)
        return doGrassAnimation(worldTime, worldSpacePosition, midBlock, 1);
    if (id == 10020)
        return doGrassAnimation(worldTime, worldSpacePosition, midBlock, 2);
    if (id == 10010)
        return doGrassAnimation(worldTime, worldSpacePosition, midBlock, 3);
    if (id == 10011)
        return doGrassAnimation(worldTime, worldSpacePosition, midBlock, 4);
    
    return worldSpacePosition;
}
