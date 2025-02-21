#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"
#include "/lib/depth_of_field.glsl"

// mipmap bloom
#if BLOOM_TYPE == 2
    const bool colortex1MipmapEnabled = true;
#endif

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex1; // bloom
uniform sampler2D colortex2; // depth of field
uniform sampler2D colortex3; // TAA

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec4 taaData;

/*******************************************/
/**** bloom & depth of field : 2nd pass ****/
/*******************************************/
void main() {
    // -- depth of field -- //
    #if DOF_TYPE > 0
        vec4 depthOfFieldData = vec4(0.0);
        vec3 DOF = depthOfField(uv, colortex0, colortex2, DOF_RANGE, DOF_RESOLUTION, DOF_STD, DOF_KERNEL == 1, false, depthOfFieldData);
        vec3 color = DOF;
    #else
        vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);
    #endif

    // -- bloom -- //
    #if BLOOM_TYPE == 1
        vec3 bloom = blur(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        color += bloom * BLOOM_FACTOR;
    #elif BLOOM_TYPE == 2
        float range = 0.1 * BLOOM_RANGE;
        int n = 2;
        vec3 bloom = vec3(0.0);

        for (int lod=3; lod<7; ++lod) {
            float blurSize = pow(2.0, float(lod)) / 2;

            // get noise
            float noise = pseudoRandom(uv+0.1*lod + frameTimeCounter);
            float theta = noise * 2.0*PI;
            float cosTheta = cos(theta);
            float sinTheta = sin(theta);
            // rotation matrix
            mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

            for (int x=-n; x<=n; ++x) {
                for (int y=-n; y<=n; ++y) {
                    vec2 offset = vec2(x, y) * blurSize / vec2(viewWidth, viewHeight);
                    offset = rotation * offset;
                    float lodFactor = (1.0 - 0.12*lod);
                    float weight = lodFactor * gaussian(x/n, y/n, 0.5);
                    bloom += 0.1 * weight * texture2DLod(colortex1, uv+offset, lod).rgb;
                }
            }
        }

        color += 0.3 * bloom * BLOOM_FACTOR;
    #endif

    if (frameTimeCounter > 0.0) {
        vec3 taa = SRGBtoLinear(texture2D(colortex3, uv).rgb);
        color = mix(color, taa, 0.5);
    }

    colorData = vec4(linearToSRGB(color), 1.0);
    taaData = vec4(linearToSRGB(color), 1.0);
}
