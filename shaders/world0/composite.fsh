#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/color.glsl"
#include "/lib/sample.glsl"
#include "/lib/shadow.glsl"

// textures
uniform sampler2D colortex0; // opaque albedo
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex3; // opaque material (type, smoothness, reflectance)
uniform sampler2D colortex4; // transparent albedo
uniform sampler2D colortex5; // transparent normal
uniform sampler2D colortex6; // transparent light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex7; // transparent material (type, smoothness, reflectance)
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

// constant
const float ambiantFactor_opaque = 0.2;
const float ambiantFactor_transparent = 1;

// attributes
in vec3 skyLightColor;
in vec3 blockLightColor;
in vec3 fog_color;
in float shadowDayNightBlend;
in float rainFactor;
in float fog_density;

in vec2 uv;

// TODO: be sure to normalize sample vec par rapport à l'espace view
float SSAO(vec2 uv, float depth, mat3 TBN) {
    // handle SSAO_SAMPLES<1 by skipping SSAO
    if (SSAO_SAMPLES<1)
        return 1;

    vec3 viewSpacePosition = screenToView(uv, depth);

    float occlusion = 0;
    float weigthts = 0;
    for (int i=0; i<SSAO_SAMPLES; ++i) {
        vec3 sampleTangentSpace = getSample(uv, i);
        vec3 sampleViewSpace = tangentToView(sampleTangentSpace, TBN);

        // offset and scale
        sampleViewSpace = sampleViewSpace * SSAO_RADIUS + viewSpacePosition;

        // convert from view to screen space
        vec3 sampleUV = viewToScreen(sampleViewSpace);

        // test if occluded
        float sampleDepth = texture2D(depthtex0, sampleUV.xy).r;
        if (sampleDepth + SSAO_BIAS > depth) {
            float weight = length(sampleTangentSpace);
            weigthts += weight;
            occlusion += mix(0, 1, weight/SSAO_RADIUS); // atenuate depending on sample radius
        }
    }
    if (weigthts > 0) {
        occlusion /= weigthts;
    }

    return occlusion;
}

vec4 lighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, float depth, float smoothness, float reflectance, float subsurface,
              float ambiantSkyLightIntensity, float blockLightIntensity, float emissivness, float ambient_occlusion, bool isTransparent) {

    float ambiantFactor = isTransparent ? ambiantFactor_transparent : ambiantFactor_opaque;

    // TODO: SSAO
    float occlusion = 1;
    
    // directions and angles 
    vec3 LightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(LightDirectionWorldSpace, normal);
    vec3 worldSpacePosition = viewToWorld(screenToView(uv, depth));
    vec3 worldSpaceViewDirection = normalize(cameraPosition - worldSpacePosition);
    float distanceFromCamera = distance(cameraPosition, worldSpacePosition);
    float linearDepth = distanceFromCamera / far;
    float cosTheta = dot(worldSpaceViewDirection, normal);

    /* shadow */
    vec4 shadow = vec4(0);
    if (distanceFromCamera < endShadowDecrease)
        shadow = getSoftShadow(uv, depth, gbufferProjectionInverse, gbufferModelViewInverse);
    // fade into the distance
    float shadow_fade = 1 - map(distanceFromCamera, startShadowDecrease, endShadowDecrease, 0, 1);
    shadow.a *= shadow_fade; 
    // emissive block don't have shadows on them
    shadow.a = mix(shadow.a, 0, emissivness);

    /* lighting */
    // direct sky light
    vec3 skyDirectLight = max(lightDirectionDotNormal, 0) * skyLightColor;
    // subsurface scattering
    if (ambient_occlusion > 0) {
        float subsurface_fade = map(distanceFromCamera, endShadowDecrease, startShadowDecrease, 0.2, 1);
        skyDirectLight = max(lightDirectionDotNormal, subsurface_fade) * skyLightColor;
        skyDirectLight *= ambient_occlusion;
    }
    skyDirectLight *= rainFactor * shadowDayNightBlend; // reduce contribution as it rains or during day-night transition
    skyDirectLight = mix(skyDirectLight, skyDirectLight * shadow.rgb, shadow.a); // apply shadow
    // ambiant sky light
    vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity;
    // block light
    if (emissivness > 0) blockLightIntensity *= 1.5;
    blockLightIntensity *= (1+emissivness);
    vec3 blockLight = blockLightColor * blockLightIntensity;
    // attenuate light underwater
    if (!isTransparent && (isEyeInWater==1 || isWater(texture2D(colortex7, uv).x))) {
        skyDirectLight *= ambiantSkyLightIntensity;
    }
    // perfect diffuse
    vec3 color = albedo * occlusion * (skyDirectLight + ambiantSkyLight + blockLight);
    // color = clamp(color * (emissivness*2 + 1), 0, 1);

    /* BRDF */
    // float roughness = pow(1.0 - smoothness, 2.0);
    // vec3 BRDF = albedo * (ambiantSkyLight + blockLight) + skyDirectLight * brdf(LightDirectionWorldSpace, viewDirectionWorldSpace, normal, albedo, roughness, reflectance);

    /* fresnel */
    transparency = max(transparency, schlick(reflectance, cosTheta));

    /* fog */
    // vanilla fog
    if (FOG_TYPE > 0) {
        // linear function 
        float vanillaFogBlend = clamp((distanceFromCamera - fogStart) / (fogEnd - fogStart), 0, 1);
        color = mix(color, fog_color, vanillaFogBlend);
    }
    // custom fog
    if (FOG_TYPE == 2) {
        float fogDensity = getFogDensity(worldSpacePosition.y);

        // exponential function
        float customFogBlend = clamp(1 - pow(2, -pow((linearDepth * fogDensity), 2)), 0, 1); 
        color = mix(color, fog_color, customFogBlend);
    }

    // return vec4(vec3(ambient_occlusion), 1);
    return vec4(color, transparency);
}

// results
/* RENDERTARGETS: 0,1,2,3,4,5,6,7 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightData;
layout(location = 3) out vec4 opaqueMaterialData;
layout(location = 4) out vec4 transparentColorData;
layout(location = 5) out vec4 transparentNormalData;
layout(location = 6) out vec4 transparentLightData;
layout(location = 7) out vec4 transparentMaterialData;

void process(sampler2D albedoTexture, sampler2D normalTexture, sampler2D lightTexture, sampler2D materialTexture, sampler2D depthTexture,
            out vec4 colorData, out vec4 normalData, out vec4 lightData, out vec4 materialData, bool isTransparent) {
    
    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(albedoTexture, uv);
    vec3 albedo = vec3(0); float transparency = 0;
    getColorData(colorData, albedo, transparency);
    // normal
    normalData = texture2D(normalTexture, uv);
    vec3 normal = vec3(0);
    getNormalData(normalData, normal);
    // light
    lightData = texture2D(lightTexture, uv);
    float blockLightIntensity = 0, ambiantSkyLightIntensity = 0, emissivness = 0, ambient_occlusion = 0;
    getLightData(lightData, blockLightIntensity, ambiantSkyLightIntensity, emissivness, ambient_occlusion);
    // material
    materialData = texture2D(materialTexture, uv);
    float type = 0, smoothness = 0, reflectance = 0, subsurface = 0;
    getMaterialData(materialData, type, smoothness, reflectance, subsurface);
    // depth
    vec4 depthData = texture2D(depthTexture, uv);
    float depth = 0;
    getDepthData(depthData, depth);

    // -- light computation -- //
    // basic or glowing
    if (isBasic(type)) {
        if (isTransparent) {
            opaqueColorData += vec4(albedo, transparency) * 1.5;
        }
        else {
            colorData = vec4(albedo, transparency);
        }
        
    } 
    // lit
    else {
        colorData = lighting(
            uv, 
            albedo, 
            transparency, 
            normal, 
            depth,
            smoothness,
            reflectance,
            subsurface,
            ambiantSkyLightIntensity, 
            blockLightIntensity,
            emissivness,
            ambient_occlusion,
            isTransparentLit(type)
        );
        // colorData = vec4(1,1,0,1);
    }

    // convert back to SRGB
    colorData.rgb = linearToSRGB(colorData.rgb);
}

/*****************************************
************* lighting & fog *************
******************************************/
void main() {
    process(colortex0, colortex1, colortex2, colortex3, depthtex1, opaqueColorData, opaqueNormalData, opaqueLightData, opaqueMaterialData, false);
    process(colortex4, colortex5, colortex6, colortex7, depthtex0, transparentColorData, transparentNormalData, transparentLightData, transparentMaterialData, true);
}
