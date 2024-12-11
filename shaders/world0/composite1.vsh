#version 140

// includes
#include "/lib/common.glsl"

// left right bottom top near far
out vec3 planes_normal[6];
out vec3 planes_point[6];
out vec3 backgroundColor;

out vec2 uv;

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

void main() {

    // -- FRUSTUM PLANES -- //
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
    for (int i=0; i<6; ++i) {
        vec3 normal = - normalize(planesData[i].xyz);

        vec3 point = vec3(0.0);
        if (planesData[i].x != 0.0) {
            point.x = -planesData[i].w / planesData[i].x;
        } else if (planesData[i].y != 0.0) {
            point.y = -planesData[i].w / planesData[i].y;
        } else if (planesData[i].z != 0.0) {
            point.z = -planesData[i].w / planesData[i].z;
        }

        planes_normal[i] = normal;
        planes_point[i] = point;
    }

    // background reflection color
    // TODO: gérer le fog dans les grottes
    backgroundColor = mix(0.5*fogColor, skyColor, float(eyeBrightness.y)/255.);

    gl_Position = ftransform();
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
