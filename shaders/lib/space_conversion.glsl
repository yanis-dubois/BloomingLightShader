#ifndef "/lib/common.glsl"
#define "/lib/common.glsl"

vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

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

vec3 texelToScreen(vec3 texelPosition) {
    return texelPosition / vec3(viewWidth, viewHeight, 1);
}

vec3 tangentToView(vec3 tangentPosition, mat3 TBN) {
    return TBN * tangentPosition;
}

#endif
