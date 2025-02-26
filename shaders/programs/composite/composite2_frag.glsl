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
uniform sampler2D depthtex0; // depth all
#if TAA == 1
    uniform sampler2D colortex3; // TAA
#endif

// attributes
in vec2 uv;

// results
#if TAA == 1
    /* RENDERTARGETS: 0,3 */
    layout(location = 0) out vec4 colorData;
    layout(location = 1) out vec4 taaData;
#else
    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec4 colorData;
#endif

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
    #if TAA == 1
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

                vec2 pixelVelocity = (uv - prevUV) * vec2(viewWidth, viewHeight);
                // depth reject
                float blendFactor = 1.0 - smoothstep(0.0, 0.005, abs(previousDepth - depth));
                // pixel velocity reject
                // blendFactor *= 1.0 - smoothstep(0.0, 1.0, length(pixelVelocity));

                // neighborhood clipping
                vec3 minColor = vec3(1.0), maxColor = vec3(0.0);
                for (int i=-2; i<=2; i+=2) {
                    for (int j=-2; j<=2; j+=2) {
                        if (i==0 && j==0) continue;
                        vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
                        vec3 neighborColor = SRGBtoLinear(texture2D(colortex0, uv + offset).rgb);

                        minColor = min(minColor, neighborColor);
                        maxColor = max(maxColor, neighborColor);
                    } 
                }
                previousColor = clamp(previousColor, minColor, maxColor);

                color = mix(color, previousColor, 0.8 * blendFactor);
            }   
        }
        // wild effect
        // {
        //     vec4 taaData = texture2D(colortex3, uv);
        //     vec3 previousColor = SRGBtoLinear(taaData.rgb);
        //     color = mix(color, previousColor, 0.92);
        // }
        taaData = vec4(linearToSRGB(color), depth);
    #endif

    // -- bloom -- //
    #if BLOOM_TYPE == 1
        vec3 bloom = blur(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        color += bloom * BLOOM_FACTOR;
    #elif BLOOM_TYPE == 2
        vec3 bloom = bloom(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        bloom = pow(bloom, 1.0 / vec3(1.75));
        color += bloom * BLOOM_FACTOR;
    #elif BLOOM_TYPE == 3
        int n = 2; // 2
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
                    float weight = 0.03 * lodFactor * gaussian(x/n, y/n, 0.5); // 0.03

                    bloom += weight * texture2DLod(colortex1, uv+offset, lod).rgb;
                }
            }
        }

        color += bloom * BLOOM_FACTOR;
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
}
