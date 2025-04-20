vec2 doPOM(sampler2D normals, mat3 TBN, vec3 viewDirection, vec2 localTextureCoordinate, vec4 textureCoordinateOffset) {

    if (!isInRange(localTextureCoordinate, 0.01, 0.99)) {
        return localTextureCoordinate * textureCoordinateOffset.xy + textureCoordinateOffset.zw;
    }

    int nbSteps = 64;
    vec3 tangentSpaceViewDirection = transpose(TBN) * viewDirection;

    float heightScale = 2.0/16.0;
    float layerDepth = 1.0;
    float stepSize = layerDepth / float(nbSteps);

    vec2 P = tangentSpaceViewDirection.xy / tangentSpaceViewDirection.z * heightScale;
    vec2 deltaUV = - P * stepSize;

    vec2 rayUV = localTextureCoordinate;
    float rayDepth = 0.0;
    float currentHeight = 1.0 - texture2D(normals, rayUV * textureCoordinateOffset.xy + textureCoordinateOffset.zw).a;

    // raymarching loop
    for (int i = 0; i < nbSteps; ++i) {
        if (rayDepth >= currentHeight)
            break;
        if (!isInRange(rayUV, 0.1, 0.9)) {
            rayUV -= deltaUV;
            break;
        }

        rayUV += deltaUV;
        rayDepth += stepSize;
        currentHeight = 1.0 - texture2D(normals, rayUV * textureCoordinateOffset.xy + textureCoordinateOffset.zw).a;            
    }

    return rayUV * textureCoordinateOffset.xy + textureCoordinateOffset.zw;
}
