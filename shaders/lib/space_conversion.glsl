#ifndef "/lib/common.glsl"
#define "/lib/common.glsl"

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float viewHeight;
uniform float viewWidth;

vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

vec4 addMatrixRows(int row1, int row2) {
    return vec4(
        gbufferProjection[0][row1] + gbufferProjection[0][row2],
        gbufferProjection[1][row1] + gbufferProjection[1][row2],
        gbufferProjection[2][row1] + gbufferProjection[2][row2],
        gbufferProjection[3][row1] + gbufferProjection[3][row2]
    );
}

vec4 subtractMatrixRows(int row1, int row2) {
    return vec4(
        gbufferProjection[0][row1] - gbufferProjection[0][row2],
        gbufferProjection[1][row1] - gbufferProjection[1][row2],
        gbufferProjection[2][row1] - gbufferProjection[2][row2],
        gbufferProjection[3][row1] - gbufferProjection[3][row2]
    );
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
    // bool behind = NDCPosition.z < -1;
    // vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, NDCPosition);
    // if (behind) viewPosition.z = - (viewPosition.z + near) - near;
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

// in my specific case there can be only one intersection
vec3 segmentFrustumIntersection(vec3 positionA, vec3 positionB) {

    vec3 nearBottomLeftCorner = NDCToView(vec3(-1));
    vec3 farTopRightCorner = NDCToView(vec3(1));

    vec3 points[6] = vec3[](
        vec3(0,0.5,0.5), // left
        vec3(1,0.5,0.5), // right
        vec3(0.5,0,0.5), // bottom
        vec3(0.5,1,0.5), // top
        vec3(0.5,0.5,0), // near
        vec3(0.5,0.5,1) // far
    );

    // extract frustum planes [TODO: calcul only 1 time]
    vec3 normals[6] = vec3[](
        addMatrixRows(3, 0).xyz, // left
        subtractMatrixRows(3, 0).xyz, // right
        addMatrixRows(3, 1).xyz, // bottom
        subtractMatrixRows(3, 1).xyz, // top
        addMatrixRows(3, 2).xyz, // near
        subtractMatrixRows(3, 2).xyz // far
    );
    for (int i=0; i<6; ++i) {
        points[i] = NDCToView(points[i]);
        normals[i] = normalize((normals[i]));
    }

    vec3 segmentDirection = normalize(positionB - positionA);

    // get intersections
    bool hasIntersection[6];
    vec3 intersections[6];
    for (int i=0; i<6; ++i) {
        hasIntersection[i] = true;

        vec3 point = points[i];
        vec3 normal = normals[i];

        float denom = dot(normal, segmentDirection);
        // segment parallel to the plane
        if (denom < 0.0001) {
            hasIntersection[i] = false;
            continue;
        }

        // compute intersection
        float t = - (dot(normal, (positionA - point))) / denom;
        //t = abs(t);
        if (0 <= t && t <= 1) {
            intersections[i] = positionA + t * segmentDirection;
        } else {
            hasIntersection[i] = false;
        }
    }

    return vec3(hasIntersection[0]);

    // // get intersections
    // bool hasIntersection[6];
    // vec3 intersections[6];
    // for (int i=0; i<6; ++i) {
    //     hasIntersection[i] = true;

    //     vec3 point = points[i];
    //     vec3 normal = normals[i];

    //     float denom = dot(normal, segmentDirection);
    //     // segment parallel to the plane
    //     if (denom < 1e-6) {
    //         hasIntersection[i] = false;
    //         continue;
    //     }

    //     // compute intersection
    //     float t = - (dot(normal, (positionA - point))) / denom;
    //     //t = abs(t);
    //     if (0 <= t && t <= 1) {
    //         intersections[i] = positionA + t * segmentDirection;
    //     } else {
    //         hasIntersection[i] = false;
    //     }
    // }

    // keep only intersections that are inside frustum
    // for (int i=0; i<6; ++i) {
    //     if (!hasIntersection[i]) continue;

    //     bool isInside = true;
    //     for (int j=0; j<6; ++j) {
    //         if (dot(planes[j].xyz, intersections[i]) + planes[j].w > 0) {
    //             isInside = false;
    //             break;
    //         }
    //     }

    //     if (isInside) return intersections[i];
    // }

    return positionB;
}

#endif
