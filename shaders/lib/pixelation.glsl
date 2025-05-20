// this functions cames from Complementary shader !

// offset to the center of the surface texel, in screen space
vec2 computeTexelOffset(sampler2D tex, vec2 uv) {
    vec2 texSize = textureSize(tex, 0);
    vec4 texelSize = vec4(1.0 / texSize.xy, texSize.xy);

    // 1. Calculate how much the texture UV coords need to shift to be at the center of the nearest texel.
    vec2 uvCenter = (floor(uv * texelSize.zw) + 0.5) * texelSize.xy;
    vec2 dUV = uvCenter - uv;

    // 2. Calculate how much the texture coords vary over fragment space.
    //     This essentially defines a 2x2 matrix that gets texture space (UV) deltas from fragment space (ST) deltas.
    vec2 dUVdS = dFdx(uv);
    vec2 dUVdT = dFdy(uv);

    if (abs(dUVdS) + abs(dUVdT) == vec2(0.0)) return vec2(0.0);

    // 3. Invert the texture delta from fragment delta matrix. Where the magic happens.
    mat2x2 dSTdUV = mat2x2(dUVdT[1], -dUVdT[0], -dUVdS[1], dUVdS[0]) * (1.0 / (dUVdS[0] * dUVdT[1] - dUVdT[0] * dUVdS[1]));

    // 4. Convert the texture delta to fragment delta.
    vec2 dST = dUV * dSTdUV;
    return dST;
}

vec4 texelSnap(vec4 value, vec2 texelOffset) {
    if (texelOffset == vec2(0.0)) return value;
    vec4 dx = dFdx(value);
    vec4 dy = dFdy(value);

    vec4 valueOffset = dx * texelOffset.x + dy * texelOffset.y;
    valueOffset = clamp(valueOffset, -1.0, 1.0);

    return value + valueOffset;
}

// apply offset to a certain value (position, light intensity, ...)
vec3 texelSnap(vec3 value, vec2 texelOffset) {
    if (texelOffset == vec2(0.0)) return value;
    vec3 dx = dFdx(value);
    vec3 dy = dFdy(value);

    vec3 valueOffset = dx * texelOffset.x + dy * texelOffset.y;
    valueOffset = clamp(valueOffset, -1.0, 1.0);

    return value + valueOffset;
}


