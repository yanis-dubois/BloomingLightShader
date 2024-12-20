#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/sample.glsl"
#include "/lib/shadow.glsl"

// textures
uniform sampler2D colortex0; // opaque albedo
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex3; // opaque material (smoothness, reflectance, emissivness)
uniform sampler2D colortex4; // transparent albedo
uniform sampler2D colortex5; // transparent normal
uniform sampler2D colortex6; // transparent light (block_light, sky_ambiant_light, emmissivness)
uniform sampler2D colortex7; // transparent material (smoothness, reflectance, emissivness)
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

vec4 lighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, float depth, float smoothness, float reflectance,
              float ambiantSkyLightIntensity, float blockLightIntensity, float emissivness, bool isTranslucent) {

    float ambiantFactor = isTranslucent ? ambiantFactor_transparent : ambiantFactor_opaque;

    // TODO: SSAO
    float occlusion = 1;
    
    // directions and angles
    vec3 LightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightDirectionDotNormal = dot(LightDirectionWorldSpace, normal);
    if (isTranslucent) lightDirectionDotNormal = abs(lightDirectionDotNormal);
    vec3 viewSpacePosition = screenToView(uv, depth);
    vec3 viewSpaceViewDirection = normalize(viewSpacePosition);
    vec3 worldSpacePosition = viewToWorld(viewSpacePosition);
    vec3 viewDirectionWorldSpace = normalize(cameraPosition - worldSpacePosition);
    float distanceFromCamera = distance(viewToWorld(vec3(0)), worldSpacePosition);
    float linearDepth = distanceFromCamera / far;
    vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal);
    float cosTheta = dot(-viewSpaceViewDirection, viewSpaceNormal);

    /* shadow */
    vec4 shadow = getSoftShadow(uv, depth, gbufferProjectionInverse, gbufferModelViewInverse);
    // reduce contribution as it rains or during day-night transition
    shadow.a *= rainFactor * shadowDayNightBlend;
    // fade into the distance
    shadow.a *= 1 - map(distanceFromCamera, startShadowDecrease, endShadowDecrease, 0, 1);
    if (distanceFromCamera > endShadowDecrease) shadow.a = 0;

    /* lighting */
    // direct sky light
    vec3 skyDirectLight = max(lightDirectionDotNormal, 0) * skyLightColor;
    skyDirectLight *= rainFactor ; // * shadowDayNightBlend; // reduce contribution as it rains or during day-night transition
    skyDirectLight = mix(skyDirectLight, shadow.rgb * skyLightColor, shadow.a); // apply shadow
    // ambiant sky light
    vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity;
    // block light
    if (emissivness == 1) blockLightIntensity = 2; // enhance emissive light
    vec3 blockLight = blockLightColor * blockLightIntensity;
    // perfect diffuse
    vec3 color = albedo * occlusion * (skyDirectLight + ambiantSkyLight + blockLight);

    /* BRDF */
    // float roughness = pow(1.0 - smoothness, 2.0);
    // vec3 BRDF = albedo * (ambiantSkyLight + blockLight) + skyDirectLight * brdf(LightDirectionWorldSpace, viewDirectionWorldSpace, normal, albedo, roughness, reflectance);

    /* fresnel */
    transparency = max(transparency, schlick(reflectance, cosTheta));

    /* fog */
    // custom fog
    float customFogBlend = clamp(1 - pow(2, -pow((linearDepth*fog_density), 2)), 0, 1); // exponential function
    color = mix(color, fog_color, customFogBlend);
    // vanilla fog
    float vanillaFogBlend = clamp((distanceFromCamera - fogStart) / (fogEnd - fogStart), 0, 1);
    color = mix(color, fog_color, vanillaFogBlend);

    return vec4(color, transparency);
}

// results
/* RENDERTARGETS: 0,1,2,3,4,5,6,7 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightAndTypeData;
layout(location = 3) out vec4 opaqueMaterialData;
layout(location = 4) out vec4 transparentColorData;
layout(location = 5) out vec4 transparentNormalData;
layout(location = 6) out vec4 transparentLightData;
layout(location = 7) out vec4 transparentMaterialData;

/*****************************************
************* lighting & fog *************
******************************************/
void main() {

    /* opaque buffers values */
    // albedo
    vec4 albedoData_opaque = texture2D(colortex0, uv);
    albedoData_opaque = SRGBtoLinear(albedoData_opaque);
    vec3 albedo_opaque = albedoData_opaque.rgb;
    float transparency_opaque = albedoData_opaque.a;
    // normal
    vec4 normalData_opaque = texture2D(colortex1, uv);
    vec3 normal_opaque = decodeNormal(normalData_opaque.xyz);
    // light
    vec4 lightData_opaque = texture2D(colortex2, uv);
    vec2 receivedLight_opaque = lightData_opaque.xy;
    receivedLight_opaque = SRGBtoLinear(receivedLight_opaque);
    float blockLightIntensity_opaque = receivedLight_opaque.x;
    float ambiantSkyLightIntensity_opaque = receivedLight_opaque.y;
    float emissivness_opaque = lightData_opaque.z;
    // material
    vec4 materialData_opaque = texture2D(colortex3, uv);
    float type_opaque = materialData_opaque.x;
    float smoothness_opaque = materialData_opaque.y;
    float reflectance_opaque = materialData_opaque.z;
    // depth
    float depth_opaque = texture2D(depthtex1, uv).x;

    /* transparent buffers values */
    // albedo
    vec4 albedoData_transparent = texture2D(colortex4, uv);
    albedoData_transparent = SRGBtoLinear(albedoData_transparent);
    vec3 albedo_transparent = albedoData_transparent.rgb;
    float transparency_transparent = albedoData_transparent.a;
    // normal
    vec4 normalData_transparent = texture2D(colortex5, uv);
    vec3 normal_transparent = normalData_transparent.xyz *2 -1;
    // light
    vec4 lightData_transparent = texture2D(colortex6, uv);
    vec2 receivedLight_transparent = lightData_transparent.xy;
    receivedLight_transparent = SRGBtoLinear(receivedLight_transparent);
    float blockLightIntensity_transparent = receivedLight_transparent.x;
    float ambiantSkyLightIntensity_transparent = receivedLight_transparent.y;
    float emissivness_transparent = lightData_transparent.z;
    // material
    vec4 materialData_transparent = texture2D(colortex7, uv);
    float type_transparent = materialData_transparent.x;
    float smoothness_transparent = materialData_transparent.y;
    float reflectance_transparent = materialData_transparent.z;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;


    // -- WRITE STATIC BUFFERS -- //
    opaqueNormalData = normalData_opaque;
    opaqueMaterialData = materialData_opaque;
    opaqueLightAndTypeData = lightData_opaque;
    transparentNormalData = normalData_transparent;
    transparentLightData = lightData_transparent;
    transparentMaterialData = materialData_transparent;

    // -- INIT DYNAMIC BUFFERS -- //
    opaqueColorData = vec4(0);
    transparentColorData = vec4(0);


    // view space pos
    vec3 viewSpacePosition = screenToView(uv, depth_opaque);

    // view space normal
    vec3 viewSpaceNormal = normalize(mat3(gbufferModelView) * normal_opaque);

    // view space tangent 
    vec3 t1 = cross(normal_opaque, vec3(0,0,1));
    vec3 t2 = cross(normal_opaque, vec3(0,1,0));
    vec3 tangent = length(t1)>length(t2) ? t1 : t2;
    tangent = normalize(tangent);
    vec3 viewSpaceTangent = mat3(gbufferModelView) * tangent;

    // view space bitangent
    vec3 viewSpaceBitangent = cross(viewSpaceTangent, viewSpaceNormal);
    viewSpaceBitangent = normalize(viewSpaceBitangent);

    // tbn
    mat3 TBN = mat3(viewSpaceTangent, viewSpaceBitangent, viewSpaceNormal);

    // -- Screen Space Ambiant Occlusion -- //
    float occlusion = SSAO(uv, depth_all, TBN);
    occlusion = map(occlusion, 0, 1, 0.2, 1);

    // -- BASIC MATERIAL -- //
    if (type_opaque == 0) {
        opaqueColorData += vec4(albedo_opaque, transparency_opaque);

        // opaqueColorData = vec4(1,0,0,1);
        // opaqueColorData = vec4(vec3(lightData_opaque.z), 1);
    } 
    // -- LIT MATERIAL -- //
    else if (type_opaque >= 0.9) {
        opaqueColorData += lighting(
            uv, 
            albedo_opaque, 
            transparency_opaque, 
            normal_opaque, 
            depth_opaque,
            smoothness_opaque,
            reflectance_opaque,
            ambiantSkyLightIntensity_opaque, 
            blockLightIntensity_opaque,
            emissivness_opaque,
            false
        );

        // opaqueColorData = vec4(1,1,0,1);
        // opaqueColorData = vec4(vec3(normal_opaque), 1);
    }

    // -- GLOWING MATERIAL-- //
    if (type_transparent < 0.9) {
        // add it
        if (type_transparent == 0) {
            opaqueColorData += albedoData_transparent;
            transparentColorData += albedoData_transparent;
        }
        // mix it
        else if (0.49 < type_transparent && type_transparent < 0.51) {
            transparentColorData = vec4(albedo_transparent, transparency_transparent);
        }

        // transparentColorData = vec4(0,1,1,1);
    }
    // -- TRANSPARENT MATERIAL -- //
    else if (depth_all<depth_opaque && transparency_transparent>alphaTestRef) {
        transparentColorData += lighting(
            uv, 
            albedo_transparent, 
            transparency_transparent, 
            normal_transparent, 
            depth_all, 
            smoothness_transparent,
            reflectance_transparent,
            ambiantSkyLightIntensity_transparent, 
            blockLightIntensity_transparent,
            emissivness_transparent,
            true
        );
        
        // transparentColorData = vec4(0,0,1,1);
    }

    opaqueColorData.rgb *= 1.5;
    transparentColorData.rgb *= 1.5;

    opaqueColorData = linearToSRGB(opaqueColorData);
    transparentColorData = linearToSRGB(transparentColorData);
}
