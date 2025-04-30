vec2 localToAtlasTextureCoordinates(vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {
    return localTextureCoordinate * textureCoordinateOffset.xy + textureCoordinateOffset.zw;
}

ivec2 localToAtlasTextureCoordinatesInt(vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {
    return ivec2(localTextureCoordinate + textureCoordinateOffset.zw);
}

// row
vec2 doBasicPOM(sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset, float worldSpaceDistance) {

    ivec2 texSize = textureSize(normals, 0);
    vec4 textureCoordinateOffsetInt = vec4(
        textureCoordinateOffset.xy * texSize,
        textureCoordinateOffset.zw * texSize
    );

    int nbSteps = 64;
    vec3 tangentSpaceViewDirection = transpose(TBN) * viewDirection;

    float layerDepth = 1.0;
    float stepSize = layerDepth / float(nbSteps);

    vec2 P = (tangentSpaceViewDirection.xy / tangentSpaceViewDirection.z) * (map(worldSpaceDistance, PBR_POM_DISTANCE, PBR_POM_DISTANCE - 8.0, 0.0, 1.0) * PBR_POM_DEPTH);
    vec2 deltaUV = - P * stepSize;

    vec2 rayPosition = localTextureCoordinate;
    float rayDepth = 0.0;
    float currentHeight = 1.0 - texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy * textureCoordinateOffsetInt.xy, textureCoordinateOffsetInt), 0).a;

    if (currentHeight <= 0.001) 
        return localToAtlasTextureCoordinates(localTextureCoordinate, textureCoordinateOffset);

    // raymarching loop
    for (int i=0; i<nbSteps; ++i) {

        if (!isInRange(rayPosition, 0.0, 1.0)) {
            rayPosition -= deltaUV;
            break;
        }

        if (rayDepth >= currentHeight) {
            break;
        }

        rayPosition += deltaUV;
        rayDepth += stepSize;
        currentHeight = 1.0 - texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy * textureCoordinateOffsetInt.xy, textureCoordinateOffsetInt), 0).a;          
    }

    return localToAtlasTextureCoordinates(rayPosition, textureCoordinateOffset);
}

// pixel perfect 3D ?
vec2 doCustomPOM(sampler2D texture, sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset, float worldSpaceDistance) {

    // 
    ivec2 texSize = textureSize(texture, 0);
    textureCoordinateOffset.xy *= texSize;
    textureCoordinateOffset.zw *= texSize;
    int nbSteps = int(textureCoordinateOffset.x + textureCoordinateOffset.y) + 16;

    // ray direction
    vec3 tangentSpaceViewDirection = transpose(TBN) * viewDirection;
    vec3 rayDirection = - tangentSpaceViewDirection;
    rayDirection.z *= clamp(pow(1 - (map(worldSpaceDistance, PBR_POM_DISTANCE, PBR_POM_DISTANCE - 8.0, 0.0, 1.0) * PBR_POM_DEPTH), 2.5), 1.0/16.0, 15.0/16.0);

    vec3 rayPosition = vec3(localTextureCoordinate * textureCoordinateOffset.xy, 0.0);
    vec3 rayIntPosition = floor(rayPosition);
    float rayDepth = 0.0;

    vec4 normalData = texelFetch(normals, localToAtlasTextureCoordinatesInt(rayIntPosition.xy, textureCoordinateOffset), 0);
    if (normalData.x + normalData.y <= 0.001 || normalData.a >= 0.99) {
        rayPosition = rayIntPosition;
        return (rayPosition.xy / texSize) + (textureCoordinateOffset.zw / texSize);
    }

    float textureDepth = 1.0 - normalData.a;

    ivec3 intStep = ivec3(
        rayDirection.x > 0.0 ? 1 : -1,
        rayDirection.y > 0.0 ? 1 : -1,
        1
    );

    vec3 delta = vec3(
        rayDirection.x != 0.0 ? abs(1.0 / rayDirection.x) : 3.402823466e+38,
        rayDirection.y != 0.0 ? abs(1.0 / rayDirection.y) : 3.402823466e+38,
        rayDirection.z != 0.0 ? abs(1.0 / rayDirection.z) : 3.402823466e+38
    );

    float maxTx = rayDirection.x > 0.0 
        ? (rayIntPosition.x + 1 - rayPosition.x) / rayDirection.x 
        : (rayPosition.x - rayIntPosition.x) / - rayDirection.x;
    float maxTy = rayDirection.y > 0.0 
        ? (rayIntPosition.y + 1 - rayPosition.y) / rayDirection.y 
        : (rayPosition.y - rayIntPosition.y) / - rayDirection.y;
    float maxTz = rayDirection.z > 0.0 
        ? (rayIntPosition.z + 1 - rayPosition.z) / rayDirection.z 
        : (rayPosition.z - rayIntPosition.z) / - rayDirection.z;

    vec3 rayLastPosition = rayPosition;

    // raymarching loop
    for (int i=0; i<nbSteps; ++i) {

        if (!isInRange(rayPosition.xy, vec2(0.0), textureCoordinateOffset.xy)) {
            rayPosition = rayLastPosition;
            break;
        }

        if (rayDepth >= textureDepth) {
            break;
        }

        if (maxTz <= maxTx && maxTz <= maxTy) {
            maxTz += delta.z;
            rayIntPosition.z += intStep.z;
        } 
        else if (maxTx <= maxTy && maxTx <= maxTz) {
            maxTx += delta.x;
            rayIntPosition.x += intStep.x;
        } 
        else {
            maxTy += delta.y;
            rayIntPosition.y += intStep.y;
        }

        rayLastPosition = rayPosition;
        rayPosition = rayIntPosition;

        float t = min(min(maxTx, maxTy), maxTz);
        rayDepth = - rayDirection.z * t;

        textureDepth = 1.0 - texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy, textureCoordinateOffset), 0).a;
    }

    return (rayPosition.xy / texSize) + (textureCoordinateOffset.zw / texSize);
}

vec2 doPOM(sampler2D texture, sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset, float worldSpaceDistance) {
    #if PBR_POM == 1
        return doBasicPOM(normals, TBN, viewDirection, localTextureCoordinate, textureCoordinateOffset, worldSpaceDistance);
    #else
        return doCustomPOM(texture, normals, TBN, viewDirection, localTextureCoordinate, textureCoordinateOffset, worldSpaceDistance);
    #endif
}
