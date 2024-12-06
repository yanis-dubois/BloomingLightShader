#ifndef "/lib/common.glsl"
#define "/lib/common.glsl"

vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

vec4 addMatrixRows(mat4 matrix, int row1, int row2) {
    return vec4(
        matrix[0][row1] + matrix[0][row2],
        matrix[1][row1] + matrix[1][row2],
        matrix[2][row1] + matrix[2][row2],
        matrix[3][row1] + matrix[3][row2]
    );
}

vec4 subtractMatrixRows(mat4 matrix, int row1, int row2) {
    return vec4(
        matrix[0][row1] - matrix[0][row2],
        matrix[1][row1] - matrix[1][row2],
        matrix[2][row1] - matrix[2][row2],
        matrix[3][row1] - matrix[3][row2]
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

struct Plane {
    vec3 normal;
    vec3 point;
};

// find intersection between ray and frustum
vec3 rayFrustumIntersection(vec3 origin, vec3 direction) {

    // extract frustum planes infos from projection matrix
    vec4 planesData[6] = vec4[](
        addMatrixRows(gbufferProjection, 3, 0), // left
        subtractMatrixRows(gbufferProjection, 3, 0), // right
        addMatrixRows(gbufferProjection, 3, 1), // bottom
        subtractMatrixRows(gbufferProjection, 3, 1), // top
        addMatrixRows(gbufferProjection, 3, 2), // near
        subtractMatrixRows(gbufferProjection, 3, 2) // far
    );

    // create planes from infos
    Plane planes[6];
    for (int i=0; i<6; ++i) {
        vec3 normal = normalize(planesData[i].xyz);

        vec3 point = vec3(0.0);
        if (planesData[i].x != 0.0) {
            point.x = -planesData[i].w / planesData[i].x;
        } else if (planesData[i].y != 0.0) {
            point.y = -planesData[i].w / planesData[i].y;
        } else if (planesData[i].z != 0.0) {
            point.z = -planesData[i].w / planesData[i].z;
        }

        planes[i] = Plane(-normal, point);
    }

    // get intersections
    bool hasIntersection[6];
    vec3 intersections[6];
    for (int i=0; i<6; ++i) {
        hasIntersection[i] = true;

        vec3 normal = planes[i].normal;
        vec3 point = planes[i].point;

        float denom = dot(normal, direction);
        // segment parallel to the plane
        if (denom < 1e-6) {
            hasIntersection[i] = false;
            continue;
        }

        // compute intersection
        float t = - (dot(normal, (origin - point))) / denom;
        if (t > 0) {
            intersections[i] = origin + (t - 1e-2) * direction;
        } else {
            hasIntersection[i] = false;
        }
    }

    // keep only intersections that are inside frustum
    for (int i=0; i<6; ++i) {
        if (!hasIntersection[i]) continue;

        bool isInside = true;
        for (int j=0; j<6; ++j) {
            if (dot(-planes[j].normal, intersections[i] - planes[j].point) < 0) {
                isInside = false;
                break;
            }
        }

        if (isInside) {
            return intersections[i];
        }
    }

    return vec3(0);
}

#endif
