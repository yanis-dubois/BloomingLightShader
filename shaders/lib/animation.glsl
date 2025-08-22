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

float getNetherVolumetricFog(float time, vec3 seed) {
    seed.y *= 0.045;
    seed.xz *= 0.15;

    time = time * 0.33;
    seed.y -= time;

    float noise = snoise_4D(vec4(seed, 0.5 * time)) * 0.5 + 0.5;
    noise = smoothstep(0.7, 1.0, noise);
    return noise;
}
vec3 beamGradient[5] = vec3[](
    vec3(0.20, 0.85, 0.78),  // deep purple
    vec3(0.38, 0.42, 0.95),  // electric indigo
    vec3(0.35, 0.00, 0.52),  // rich violet
    vec3(0.45, 0.12, 0.72),  // amethyst glow
    vec3(0.20, 0.65, 1.00)   // ethereal blue
);
float getEndVolumetricFog(float time, vec3 seed, inout vec3 color) {

    // color
    float noise = snoise_3D(vec3(seed.xz * 0.0125, 0.15 * time)) * 0.5 + 0.5;
    noise = mod(noise + 0.05 * time, 1.0);
    color = mix(beamGradient[0], beamGradient[1], map(noise, 0.0, 0.2, 0.0, 1.0));
    color = mix(color, beamGradient[2], map(noise, 0.2, 0.4, 0.0, 1.0));
    color = mix(color, beamGradient[3], map(noise, 0.4, 0.6, 0.0, 1.0));
    color = mix(color, beamGradient[4], map(noise, 0.6, 0.8, 0.0, 1.0));
    color = mix(color, beamGradient[0], map(noise, 0.8, 1.0, 0.0, 1.0));

    // intensity
    noise = snoise_3D(vec3(seed.xz * 0.0125, 0.05 * time)) * 0.5 + 0.5;
    noise = smoothstep(0.5, 1.0, noise);

    return noise;
}

vec2 doHeatRefraction(float time, vec2 uv, vec3 eyeSpaceDirection, float height) {
    float heightFactor = 1.0 - map(height, seaLevel, 128.0, 0.0, 1.0);
    heightFactor *= heightFactor;
    float amplitude = 0.0033 * heightFactor;
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

    #if !defined NETHER && !defined END
        vec3 seed = vec3(worldSpacePosition.xz/10.0 - time * wind, time);
    #else
        vec3 seed = vec3(worldSpacePosition.xz/5.0, 0.75 * time);
    #endif

    worldSpacePosition.y += amplitude * snoise_3D(seed);
    return worldSpacePosition;
}

vec3 doLeafAnimation(int id, float time, vec3 worldSpacePosition, float ambientSkyLightIntensity) {
    // setup amplitude
    float amplitude = isVine(id) ? 1.0 / 16.0 : 1.0 / 6.0;
    // attenuate wind in caves
    #if !defined NETHER && !defined END
        amplitude *= ambientSkyLightIntensity;
    #endif
    if (amplitude <= 0.01) return worldSpacePosition;
    #if defined END
        time *= 0.15;
    #else
        time *= 0.2;
    #endif

    float theta;
    vec2 wind = getWind(theta);
    // rotation matrix
    mat2 rotation = rotationMatrix(theta);
    // horizontale coord
    vec2 coord = worldSpacePosition.xz;
    coord = rotation * coord;

    #if !defined NETHER && !defined END
        vec3 seed1 = vec3(
            coord.x/20.0 - time, 
            coord.y/180.0, 
            worldSpacePosition.y/50.0 + 0.1 * time
        );
        vec3 seed2 = vec3(worldSpacePosition.xz/15.0 - time * normalize(wind), worldSpacePosition.y/50.0 + 0.1 * time);
    #else 
        vec3 seed = vec3(worldSpacePosition.xz/5.0 - time, worldSpacePosition.y/10.0 + 0.15 * time);
    #endif

    #if !defined NETHER && !defined END
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
    #if !defined NETHER && !defined END
        amplitude *= ambientSkyLightIntensity;
    #endif
    if (amplitude <= 0.01) return worldSpacePosition;
    #if defined END
        time *= 0.15;
    #else
        time *= 0.2;
    #endif

    float theta;
    vec2 wind = getWind(theta);
    // rotation matrix
    mat2 rotation = rotationMatrix(theta);
    // horizontale coord
    vec2 coord = worldSpacePosition.xz;
    coord = rotation * coord;

    #if !defined NETHER && !defined END
        vec3 seed1 = vec3(
            coord.x/20.0 - time, 
            coord.y/180.0, 
            worldSpacePosition.y/50.0 + 0.1 * time
        );
        vec3 seed2 = vec3(worldSpacePosition.xz/10.0 - time, worldSpacePosition.y/50.0 + 0.1 * time);
    #else 
        vec3 seed = vec3(worldSpacePosition.xz/5.0 - time, worldSpacePosition.y/10.0 + 0.15 * time);
    #endif

    // attuenuate amplitude at the root if rooted
    if (isRooted(id)) {
        vec3 rootOrigin = midBlockToRoot_animation(id, midBlock);
        amplitude *= clamp(rootOrigin.y, 0.0, 1.0);
    }

    #if !defined NETHER && !defined END
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

vec3 doAnimation(int id, float time, vec3 playerSpacePosition, vec3 midBlock, float ambientSkyLightIntensity) {
    vec3 worldSpacePosition = playerToWorld(playerSpacePosition);

    if (hasWaterAnimation(id))
        worldSpacePosition = doWaterAnimation(time, worldSpacePosition);
    else if (hasLeavesAnimation(id))
        worldSpacePosition = doLeafAnimation(id, time, worldSpacePosition, ambientSkyLightIntensity);
    else if (hasGrassAnimation(id))
        worldSpacePosition = doGrassAnimation(id, time, worldSpacePosition, midBlock, ambientSkyLightIntensity);

    return worldToPlayer(worldSpacePosition);
}
