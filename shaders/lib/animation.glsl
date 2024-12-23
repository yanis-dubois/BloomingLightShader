
// #pragma glslify: snoise2 = require(/ext/glsl-noise/simplex/2d)
// #pragma glslify: snoise3 = require(/ext/glsl-noise/simplex/3d)
// #pragma glslify: snoise4 = require(/ext/glsl-noise/simplex/4d)

#include "/ext/glsl-noise/simplex/3d.glsl"

vec3 doWaterAnimation(float worldTime, vec3 worldSpacePosition) {
    float amplitude = 1.0/32.0;
    worldSpacePosition.y += amplitude * snoise(vec3(worldSpacePosition.xz/10.0 + worldTime/100.0, worldTime/50.0));
    return worldSpacePosition;
}

vec3 doLeafAnimation(float worldTime, vec3 worldSpacePosition) {
    float amplitude = 1.0/16.0;

    float blend = sin(worldTime/500 * 2*PI) * 0.5 + 0.5;
    float definition = mix(5.0, 10.0, blend);
    float speed = mix(80.0, 100.0, blend);

    vec3 seed = vec3(worldSpacePosition/10.0 + worldTime/100.0);

    worldSpacePosition.x += amplitude * snoise(seed);
    worldSpacePosition.y += amplitude * snoise(seed + 1.0);
    worldSpacePosition.z += amplitude * snoise(seed + 2.0);
    return worldSpacePosition;
}

vec3 doAnimation(int id, float worldTime, vec3 worldSpacePosition) {
    if (id == 20000)
        return doWaterAnimation(worldTime, worldSpacePosition);
    if (id == 10030)
        return doLeafAnimation(worldTime, worldSpacePosition);
    
    return worldSpacePosition;
}
