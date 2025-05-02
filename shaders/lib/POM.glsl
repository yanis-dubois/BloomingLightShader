vec2 localToAtlasTextureCoordinates(vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {
    return localTextureCoordinate * textureCoordinateOffset.xy + textureCoordinateOffset.zw;
}

ivec2 localToAtlasTextureCoordinatesInt(vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {
    return ivec2(localTextureCoordinate + textureCoordinateOffset.zw);
}

// basic POM implementation
// less accurate but works well with every kind of texture packs, even with the highest definitions
vec2 doBasicPOM(sampler2D texture, sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset, float worldSpaceDistance) {

    // texture atlas utils
    ivec2 texSize = textureSize(texture, 0);
    vec4 textureCoordinateOffsetInt = vec4(
        textureCoordinateOffset.xy * texSize,
        textureCoordinateOffset.zw * texSize
    );

    // POM paramters
    float layerDepth = 1.0;
    int nbSteps = 64;
    float stepSize = layerDepth / float(nbSteps);

    // ray direction
    vec3 tangentSpaceViewDirection = transpose(TBN) * viewDirection;
    vec2 P = (tangentSpaceViewDirection.xy / tangentSpaceViewDirection.z) * (map(worldSpaceDistance, PBR_POM_DISTANCE, PBR_POM_DISTANCE - 8.0, 0.0, 1.0) * PBR_POM_DEPTH);
    vec2 deltaUV = - P * stepSize;

    // ray position
    vec2 rayPosition = localTextureCoordinate;
    float rayDepth = 0.0;

    // check if there is a normal map
    vec4 normalData = texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy * textureCoordinateOffsetInt.xy, textureCoordinateOffsetInt), 0);
    if (normalData.x + normalData.y <= 0.001 || normalData.a >= 0.99) {
        return localToAtlasTextureCoordinates(rayPosition, textureCoordinateOffset);
    }

    // get texture depth 
    float textureDepth = 1.0 - normalData.a;

    // raymarching loop
    for (int i=0; i<nbSteps; ++i) {

        // hit
        if (rayDepth >= textureDepth) {
            break;
        }

        // one step further
        rayPosition += deltaUV;
        rayDepth += stepSize;

        // if out of bounds : keep on texture limits
        if (!isInRange(rayPosition, vec2(0.0), vec2(1.0))) {
            rayPosition.xy = mod(rayPosition.xy, 1.0);
        }

        textureDepth = 1.0 - texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy * textureCoordinateOffsetInt.xy, textureCoordinateOffsetInt), 0).a;          
    }

    return localToAtlasTextureCoordinates(rayPosition, textureCoordinateOffset);
}

// pixel perfect POM (DDA algorithm)
// faster with low definition textures (16x16 or 32x32 texture pack), but be carefull when using higher definition
vec2 doCustomPOM(sampler2D texture, sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset, float worldSpaceDistance, inout vec3 normal) {

    // texture atlas utils
    ivec2 texSize = textureSize(texture, 0);
    textureCoordinateOffset.xy *= texSize;
    textureCoordinateOffset.zw *= texSize;

    // maximum steps number
    int nbSteps = int(textureCoordinateOffset.x + textureCoordinateOffset.y) + 16;

    // ray direction
    vec3 tangentSpaceViewDirection = transpose(TBN) * viewDirection;
    vec3 rayDirection = - tangentSpaceViewDirection;
    rayDirection.z *= clamp(pow(1 - (map(worldSpaceDistance, PBR_POM_DISTANCE, PBR_POM_DISTANCE - 8.0, 0.0, 1.0) * PBR_POM_DEPTH), 2.5), 1.0/16.0, 15.0/16.0);

    // ray position
    vec3 rayPosition = vec3(localTextureCoordinate * textureCoordinateOffset.xy, 0.0);
    vec3 rayLastPosition = rayPosition;
    vec3 rayIntPosition = floor(rayPosition);
    float rayDepth = 0.0;
    float rayLastDepth = 0.0;

    // check if there is a normal map
    vec4 normalData = texelFetch(normals, localToAtlasTextureCoordinatesInt(rayIntPosition.xy, textureCoordinateOffset), 0);
    if (normalData.x + normalData.y <= 0.001 || normalData.a >= 0.99) {
        rayPosition = rayIntPosition;
        return (rayPosition.xy / texSize) + (textureCoordinateOffset.zw / texSize);
    }

    // get texture depth 
    float textureDepth = 1.0 - normalData.a;

    // which way we go for each axis
    ivec3 intStep = ivec3(
        rayDirection.x > 0.0 ? 1 : -1,
        rayDirection.y > 0.0 ? 1 : -1,
        1
    );

    // how fast we move for each axis
    vec3 delta = vec3(
        rayDirection.x != 0.0 ? abs(1.0 / rayDirection.x) : 3.402823466e+38,
        rayDirection.y != 0.0 ? abs(1.0 / rayDirection.y) : 3.402823466e+38,
        rayDirection.z != 0.0 ? abs(1.0 / rayDirection.z) : 3.402823466e+38
    );

    // how close we are from the next boundary for each axis
    float maxTx = rayDirection.x > 0.0 
        ? (rayIntPosition.x + 1 - rayPosition.x) / rayDirection.x 
        : (rayPosition.x - rayIntPosition.x) / - rayDirection.x;
    float maxTy = rayDirection.y > 0.0 
        ? (rayIntPosition.y + 1 - rayPosition.y) / rayDirection.y 
        : (rayPosition.y - rayIntPosition.y) / - rayDirection.y;
    float maxTz = rayDirection.z > 0.0 
        ? (rayIntPosition.z + 1 - rayPosition.z) / rayDirection.z 
        : (rayPosition.z - rayIntPosition.z) / - rayDirection.z;

    // raymarching loop
    for (int i=0; i<nbSteps; ++i) {

        // hit
        if (rayDepth >= textureDepth) {

            // hit the top of a pixel
            if (rayLastDepth < textureDepth) {
                normal = vec3(0.0);
            }

            break;
        }

        // one step further on the closest boundary (X, Y or Z)
        // Z boundary
        if (maxTz <= maxTx && maxTz <= maxTy) {
            maxTz += delta.z;
            rayIntPosition.z += intStep.z;
            normal = vec3(0.0);
        }
        // X boundary
        else if (maxTx <= maxTy && maxTx <= maxTz) {
            maxTx += delta.x;
            rayIntPosition.x += intStep.x;
            normal = vec3(- intStep.x, 0.0, 0.0);
        } 
        // Y boundary
        else {
            maxTy += delta.y;
            rayIntPosition.y += intStep.y;
            normal = vec3(0.0, - intStep.y, 0.0);
        }

        // update position
        rayLastPosition = rayPosition;
        rayPosition = rayIntPosition;

        // if out of bounds : keep on texture limits
        if (!isInRange(rayPosition.xy, vec2(0.0), textureCoordinateOffset.xy - vec2(0.001))) {
            vec2 offset = vec2(0.0);
            if (rayPosition.x < 0.0) {
                offset.x = 1.0;
            }
            if (rayPosition.y < 0.0) {
                offset.y = 1.0;
            }

            rayPosition.xy = mod(rayPosition.xy - vec2(0.001), textureCoordinateOffset.xy);
            rayPosition.xy += offset;
        }

        // update depth
        rayLastDepth = rayDepth;
        float t = min(min(maxTx, maxTy), maxTz);
        rayDepth = - rayDirection.z * t;
        textureDepth = 1.0 - texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy, textureCoordinateOffset), 0).a;
    }

    return (rayPosition.xy / texSize) + (textureCoordinateOffset.zw / texSize);
}

vec2 doPOM(sampler2D texture, sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset, float worldSpaceDistance, inout vec3 normal) {

    // init normal
    normal = vec3(0.0);

    // apply POM
    #if PBR_POM == 1
        return doBasicPOM(texture, normals, TBN, viewDirection, localTextureCoordinate, textureCoordinateOffset, worldSpaceDistance);
    #else
        return doCustomPOM(texture, normals, TBN, viewDirection, localTextureCoordinate, textureCoordinateOffset, worldSpaceDistance, normal);
    #endif
}
