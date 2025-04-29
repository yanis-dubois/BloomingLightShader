vec2 localToAtlasTextureCoordinates(vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {
    return localTextureCoordinate * textureCoordinateOffset.xy + textureCoordinateOffset.zw;
}

ivec2 localToAtlasTextureCoordinatesInt(vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {
    return ivec2(localTextureCoordinate + textureCoordinateOffset.zw);
}

// row
// vec2 doPOM(sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {

//     int nbSteps = 64;
//     vec3 tangentSpaceViewDirection = transpose(TBN) * viewDirection;

//     float heightScale = 12.0/16.0;
//     float layerDepth = 1.0;
//     float stepSize = layerDepth / float(nbSteps);

//     vec2 P = tangentSpaceViewDirection.xy / tangentSpaceViewDirection.z * heightScale;
//     vec2 deltaUV = - P * stepSize;

//     vec2 rayPosition = localTextureCoordinate;
//     rayPosition += deltaUV * abs(pseudoRandom(frameTimeCounter / 3600.0 + viewDirection));
//     float rayDepth = 0.0;
//     float currentHeight = 1.0 - texture2D(normals, localToAtlasTextureCoordinates(rayPosition, textureCoordinateOffset)).a;

//     // raymarching loop
//     for (int i=0; i<nbSteps; ++i) {

//         if (!isInRange(rayPosition, 0.0, 1.0)) {
//             rayPosition -= deltaUV;
//             break;
//         }

//         if (rayDepth >= currentHeight) {
//             break;
//         }

//         rayPosition += deltaUV;
//         rayDepth += stepSize;
//         currentHeight = 1.0 - texture2D(normals, localToAtlasTextureCoordinates(rayPosition, textureCoordinateOffset)).a;            
//     }

//     return localToAtlasTextureCoordinates(rayPosition, textureCoordinateOffset);
// }

// pixel perfect 3D ?
vec2 doPOM(sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {

    ivec2 texSize = textureSize(normals, 0);
    textureCoordinateOffset.xy *= texSize;
    textureCoordinateOffset.zw *= texSize;
    int nbSteps = int(textureCoordinateOffset.x + textureCoordinateOffset.y) + 16;

    vec3 tangentSpaceViewDirection = transpose(TBN) * viewDirection;
    float heightScale = 4.0/16.0;
    vec3 rayDirection = - tangentSpaceViewDirection;
    rayDirection.z *= heightScale;
    rayDirection = normalize(rayDirection);

    vec3 rayPosition = vec3(localTextureCoordinate * textureCoordinateOffset.xy, 0.0);
    vec3 rayInitialPosition = rayPosition;
    float rayDepth = 0.0;

    vec4 normalData = texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy, textureCoordinateOffset), 0);
    if (normalData.x + normalData.y <= 0.001 || normalData.a >= 0.99) {
        return (rayPosition.xy / texSize) + (textureCoordinateOffset.zw / texSize);
    }

    float textureDepth = 1.0 - normalData.a;

    vec3 rayIntPosition = floor(rayPosition);
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

        if (maxTx <= maxTy && maxTx <= maxTz) {
            maxTx += delta.x;
            rayIntPosition.x += intStep.x;
        } 
        else if (maxTy <= maxTx && maxTy <= maxTz) {
            maxTy += delta.y;
            rayIntPosition.y += intStep.y;
        } 
        else {
            maxTz += delta.z;
            rayIntPosition.z += intStep.z;
        }

        rayLastPosition = rayPosition;
        rayPosition = rayIntPosition;

        float t = min(min(maxTx, maxTy), maxTz);
        rayDepth = - rayDirection.z * t;

        textureDepth = 1.0 - texelFetch(normals, localToAtlasTextureCoordinatesInt(rayPosition.xy, textureCoordinateOffset), 0).a;
    }

    return (rayPosition.xy / texSize) + (textureCoordinateOffset.zw / texSize);
}
