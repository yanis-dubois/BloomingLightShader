#ifndef "/lib/common.glsl"
#define "/lib/common.glsl"

vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

mat3 generateTBN(vec3 normal) {
    // tangent 
    vec3 t1 = cross(normal, vec3(0,0,1));
    vec3 t2 = cross(normal, vec3(0,1,0));
    vec3 tangent = length(t1)>length(t2) ? t1 : t2;
    tangent = normalize(tangent);
    // bitangent
    vec3 bitangent = cross(tangent, normal);

    return mat3(tangent, bitangent, normal); 
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

vec3 viewToEye(vec3 viewPosition) {
    return mat3(gbufferModelViewInverse) * viewPosition;
}

vec3 eyeToView(vec3 eyePosition) {
    return mat3(gbufferModelView) * eyePosition;
}

vec3 eyeToWorld(vec3 eyePosition) {
    return eyePosition + eyeCameraPosition;
}

vec3 worldToEye(vec3 worldPosition) {
    return worldPosition - eyeCameraPosition;
}

vec3 worldToPlayer(vec3 worldPosition) {
    return worldPosition - cameraPosition;
}

vec3 playerToWorld(vec3 playerPosition) {
    return playerPosition + cameraPosition;
}

vec3 playerToObject(vec3 playerPosition, vec3 midBlockPosition) {
    return (playerPosition + midBlockPosition) / 32.0;
}

vec3 objectToPlayer(vec3 objectPosition, vec3 midBlockPosition) {
    return 32.0 * objectPosition - midBlockPosition;
}

vec3 viewToWorld(vec3 viewPosition) {
    return eyeToWorld(viewToEye(viewPosition));
}

vec3 worldToView(vec3 worldPosition) {
    return eyeToView(worldToEye(worldPosition));
}

vec3 screenToNDC(vec2 uv, float depth) {
    return vec3(uv, depth) * 2.0 - 1.0;
}

vec3 NDCToScreen(vec3 NDCPosition) {
    return NDCPosition * 0.5 + 0.5;
}

vec3 NDCToView(vec3 NDCPosition) {
    return projectAndDivide(gbufferProjectionInverse, NDCPosition);
}

vec3 viewToNDC(vec3 viewPosition) {
    bool behind = viewPosition.z > 0;
    vec3 NDCPosition = projectAndDivide(gbufferProjection, viewPosition);
    if (behind) NDCPosition.z = - (NDCPosition.z + 1) - 1;
    return NDCPosition;
}

vec3 screenToView(vec2 uv, float depth) {
    return NDCToView(screenToNDC(uv, depth));
}

vec3 viewToScreen(vec3 viewPosition) {
    return NDCToScreen(viewToNDC(viewPosition));
}

vec3 screenToTexel(vec3 screenPosition) {
    return screenPosition * vec3(viewWidth, viewHeight, 1);
}

vec2 screenToTexel(vec2 screenPosition) {
    return screenPosition * vec2(viewWidth, viewHeight);
}

vec3 texelToScreen(vec3 texelPosition) {
    return texelPosition / vec3(viewWidth, viewHeight, 1);
}

vec2 texelToScreen(vec2 texelPosition) {
    return texelPosition / vec2(viewWidth, viewHeight);
}

vec3 toTangentSpace(vec3 position, mat3 TBN) {
    return transpose(TBN) * position;
}

vec3 fromTangentSpace(vec3 tangentPosition, mat3 TBN) {
    return TBN * tangentPosition;
}

vec3 tangentToWorld(vec3 tangentPosition, mat3 TBN, vec3 midBlockPosition) {
    return playerToWorld(objectToPlayer(fromTangentSpace(tangentPosition, TBN), midBlockPosition));
}

#endif
