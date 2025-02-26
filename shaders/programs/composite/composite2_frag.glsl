#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"
#include "/lib/bloom.glsl"
#include "/lib/depth_of_field.glsl"

// mipmap bloom
#if BLOOM_TYPE > 1
    const bool colortex1MipmapEnabled = true;
#endif

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex1; // bloom
uniform sampler2D colortex2; // depth of field
uniform sampler2D colortex3; // TAA
uniform sampler2D depthtex0; // depth all

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

    // -- temporal anti aliasing -- //
    float depth = texture2D(depthtex0, uv).r;
    if (frameTimeCounter > 0.0) {
        // get last uv position of actual fragment
        vec3 worldSpacePosition = screenToWorld(uv, depth);
        vec3 previousPlayerSpacePosition = worldSpacePosition - previousCameraPosition;
        vec3 previousScreenSpacePosition = previousPlayerToScreen(previousPlayerSpacePosition);
        vec2 prevUV = previousScreenSpacePosition.xy;

        if (isInRange(prevUV, 0.0, 1.0)) {
            vec4 taaData = texture2D(colortex3, prevUV);
            vec3 previousColor = SRGBtoLinear(taaData.rgb);

            float previousDepth = taaData.a;
            vec3 realPreviousWorldSpacePosition = screenToWorld(uv, previousDepth);

            vec2 pixelVelocity = (uv - prevUV) * vec2(viewWidth, viewHeight);
            float blendFactor = 1 - smoothstep(0.0, 1.0, length(pixelVelocity));
            blendFactor *= 1 - smoothstep(0.0, 1.0, distance(realPreviousWorldSpacePosition, worldSpacePosition));

            color = mix(color, previousColor, 0.9 * blendFactor);
        }   
    }
    taaData = vec4(linearToSRGB(color), depth);

    // -- bloom -- //
    #if BLOOM_TYPE == 1
        vec3 bloom = blur(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        color += bloom * BLOOM_FACTOR;
    #elif BLOOM_TYPE == 2
        vec3 bloom = bloom(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        bloom = pow(bloom, 1.0 / vec3(1.75));
        color += bloom * BLOOM_FACTOR;
    #elif BLOOM_TYPE == 3
        int n = 2; // 1 | 2
        vec3 bloom = vec3(0.0);

        for (int lod=3; lod<=6; ++lod) {
            float blurSize = pow(2.0, float(lod));

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
                    // offset = rotation * offset;

                    float lodFactor = (1.0 - 0.12*lod);
                    lodFactor = exp(-lod * 0.33);
                    float weight = 0.03 * lodFactor * gaussian(x/n, y/n, 0.5); // 0.25 | 0.03

                    bloom += weight * texture2DLod(colortex1, uv+offset, lod).rgb;
                }
            }
        }

        color += bloom * BLOOM_FACTOR;
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
    //colorData = vec4(linearToSRGB(bloom), 1.0);
    //colorData = texture2D(colortex1, uv);
}
