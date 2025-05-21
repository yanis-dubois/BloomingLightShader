#include "/ext/glsl-noise/simplex/2d.glsl"
#include "/ext/glsl-noise/simplex/3d.glsl"
#include "/ext/glsl-noise/simplex/4d.glsl"

vec2 getWind(out float theta) {
    theta = 0.25 * PI;
    vec2 wind = normalize(vec2(cos(theta), sin(theta)));
    float amplitude = 1.0;

    return amplitude * wind;
}

vec2 getWind() {
    float _;
    return getWind(_);
}

float getCalmNoise(vec3 seed, float amplitude) {
    float noise = snoise_3D(seed);
    return amplitude * noise;
}
float getContrastedNoise(vec3 seed, float amplitude) {
    float noise = snoise_3D(seed);

    // base
    float noiseSign = sign(noise);
    noise = pow(abs(noise), 2.2);
    noise *= noiseSign;

    return amplitude * noise;
}
float getSpikyNoise(vec3 seed, float amplitude) {
    float noise = snoise_3D(seed);

    // spike
    float noise_2 = smoothstep(0.0, 1.0, noise);
    noise_2 = pow(abs(noise), 2.0);
    noise = (noise + noise_2) * 0.5;

    return amplitude * noise;
}

vec2 doHeatRefraction(float time, vec2 uv, vec3 eyeSpaceDirection) {
    float amplitude = 0.00165;
    time = time * 0.3;
    vec3 seed = vec3(eyeSpaceDirection * 5.25);
    eyeSpaceDirection.y *= 0.33;
    seed.y -= time;

    uv.x = amplitude * snoise_3D(seed);
    uv.y = amplitude * snoise_3D(seed + 1.0);
    return uv;
}
vec2 doWaterRefraction(float time, vec2 uv, vec3 eyeSpaceDirection) {
    float amplitude = 0.005;
    time = time * 0.15;
    vec3 seed = vec3(eyeSpaceDirection * 3.0) + time;

    uv.x = amplitude * snoise_3D(seed);
    uv.y = amplitude * snoise_3D(seed + 1.0);
    return uv;
}

// used during shadow rendering for underwater light shaft animation
float doWaterLightShaftAnimation(float time, vec3 worldSpacePosition) {
    vec2 wind = getWind();
    float amplitude = 0.33;
    time *= 0.15;
    vec3 seed = vec3(worldSpacePosition.xz * 0.5 - time * wind, 2.0 * time);

    return amplitude * snoise_3D(seed);
}

// used during shadow rendering to simulate caustic
float doWaterCausticAnimation(float time, vec3 worldSpacePosition) {
    vec2 wind = getWind();
    time *= 0.15;
    vec3 seed = vec3(worldSpacePosition.xz * 0.66 - time * wind, 2.0 * time);

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

vec3 doWaterAnimation(float time, vec3 worldSpacePosition) {
    vec2 wind = getWind();
    float amplitude = 1.0 / 32.0;
    time *= 0.25;

    vec3 seed = vec3(worldSpacePosition.xz/10.0 - time * wind, time);
    
    worldSpacePosition.y += amplitude * snoise_3D(seed);
    return worldSpacePosition;
}

vec3 doLeafAnimation(int id, float time, vec3 worldSpacePosition, float ambientSkyLightIntensity) {
    // setup amplitude
    float amplitude = isVines(id) ? 1.0 / 16.0 : 1.0 / 6.0;
    // attenuate wind in caves
    #ifndef NETHER
        amplitude *= ambientSkyLightIntensity;
    #endif
    if (amplitude <= 0.01) return worldSpacePosition;
    time *= 0.2;

    float theta;
    vec2 wind = getWind(theta);
    // rotation matrix
    mat2 rotation = rotationMatrix(theta);
    // horizontale coord
    vec2 coord = worldSpacePosition.xz;
    coord = rotation * coord;

    #ifndef NETHER
        vec3 seed1 = vec3(
            coord.x/20.0 - time, 
            coord.y/180.0, 
            worldSpacePosition.y/50.0 + 0.1 * time
        );
        vec3 seed2 = vec3(worldSpacePosition.xz/15.0 - time * normalize(wind), worldSpacePosition.y/50.0 + 0.1 * time);
    #else 
        vec3 seed = vec3(worldSpacePosition.xz/5.0 - time, worldSpacePosition.y/10.0 + 0.1 * time);
    #endif

    #ifndef NETHER
        worldSpacePosition.xz += wind * vec2(getSpikyNoise(seed1, amplitude));
        worldSpacePosition.y += getContrastedNoise(seed2, amplitude);
    #else
        amplitude *= 0.25;
        worldSpacePosition.x += getCalmNoise(seed, amplitude);
        worldSpacePosition.y += getCalmNoise(seed + 15.0, amplitude);
        worldSpacePosition.z += getCalmNoise(seed + 45.0, amplitude);
    #endif

    return worldSpacePosition;
}

// type : 0=not_rooted; 1=ground_rooted; 2=ceiling_rooted; 3=tall_ground_rooted_lower; 4=tall_ground_rooted_upper
vec3 doGrassAnimation(int id, float time, vec3 worldSpacePosition, vec3 midBlock, float ambientSkyLightIntensity) {
    float amplitude = 1.0 / 3.0;
    // attenuate wind in caves
    #ifndef NETHER
        amplitude *= ambientSkyLightIntensity;
    #endif
    if (amplitude <= 0.01) return worldSpacePosition;
    time *= 0.2;

    float theta;
    vec2 wind = getWind(theta);
    // rotation matrix
    mat2 rotation = rotationMatrix(theta);
    // horizontale coord
    vec2 coord = worldSpacePosition.xz;
    coord = rotation * coord;

    #ifndef NETHER
        vec3 seed1 = vec3(
            coord.x/20.0 - time, 
            coord.y/180.0, 
            worldSpacePosition.y/50.0 + 0.1 * time
        );
        vec3 seed2 = vec3(worldSpacePosition.xz/10.0 - time, worldSpacePosition.y/50.0 + 0.1 * time);
    #else 
        vec3 seed = vec3(worldSpacePosition.xz/5.0 - time, worldSpacePosition.y/10.0 + 0.1 * time);
    #endif

    // attuenuate amplitude at the root if rooted
    if (isRooted(id)) {
        vec3 rootOrigin = midBlockToRoot(id, midBlock);
        amplitude *= rootOrigin.y;
    }

    #ifndef NETHER
        worldSpacePosition.xz += wind * vec2(getSpikyNoise(seed1, amplitude));
        worldSpacePosition.x += getContrastedNoise(seed2, 0.25 * amplitude);
        worldSpacePosition.z += getContrastedNoise(seed2 + 15.0, 0.25 * amplitude);
    #else
        amplitude *= 0.25;
        worldSpacePosition.x += getCalmNoise(seed, amplitude);
        worldSpacePosition.z += getCalmNoise(seed + 15.0, amplitude);
    #endif
    
    return worldSpacePosition;
}

vec3 doAnimation(int id, float time, vec3 worldSpacePosition, vec3 midBlock, float ambientSkyLightIntensity) {
    if (isLiquid(id))
        return doWaterAnimation(time, worldSpacePosition);
    if (isFoliage(id))
        return doLeafAnimation(id, time, worldSpacePosition, ambientSkyLightIntensity);
    if (isUnderGrowth(id))
        return doGrassAnimation(id, time, worldSpacePosition, midBlock, ambientSkyLightIntensity);
    
    return worldSpacePosition;
}
