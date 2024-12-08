
float hash(vec2 uv, float seed) {
    // Combine UV coordinates with the seed
    vec3 p3 = fract(vec3(uv.xyx) * seed);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

// return a random sample in tangent space
vec3 getSample(vec2 uv, float seed) {
    //vec3 zetas = getNoise(uv);
    vec3 zetas = vec3(hash(uv, seed), hash(uv, seed+11.032), hash(uv, seed+402.49174));
    float theta = acos(sqrt(zetas.x));
    float phi = 2 * PI * zetas.y;
    float len = (zetas.z+0.0001) * 0.5 + 0.5;
    return len * vec3(cos(phi)*sin(theta), sin(phi)*sin(theta), cos(theta));
}
