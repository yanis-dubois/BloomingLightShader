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
uniform sampler2D colortex2; // opaque light & type : x=block_light, y=sky_ambiant_light, z=material_type[0:basic,0.5:transparent,1:lit]
uniform sampler2D colortex3; // transparent albedo
uniform sampler2D colortex4; // transparent normal
uniform sampler2D colortex5; // transparent light
uniform sampler2D colortex6; // opaque PBR
uniform sampler2D colortex7; // transparent PBR
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

// constant
const float startShadowDecrease = 140;
const float endShadowDecrease = 150;
const float ambiantFactor_opaque = 0.2;
const float ambiantFactor_transparent = 1;

// attributes
in vec3 sunLightColor;
in vec3 moonLightColor;
in vec3 skyLightColor;
in vec3 blockLightColor;
in vec3 fog_color;
in float moonPhaseBlend;
in float skyDayNightBlend;
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

vec4 lighting(vec2 uv, vec3 albedo, float transparency, vec3 normal, float depth, 
              float ambiantSkyLightIntensity, float blockLightIntensity, bool isTranslucent) {

    float ambiantFactor = isTranslucent ? ambiantFactor_transparent : ambiantFactor_opaque;

    // TODO: SSAO
    float occlusion = 1;
    
    // directions and angles
    vec3 shadowLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float shadowDirectionDotNormal = dot(shadowLightDirectionWorldSpace, normal);
    if (isTranslucent) shadowDirectionDotNormal = abs(shadowDirectionDotNormal);
    float distanceFromCamera = distance(viewToWorld(vec3(0)), viewToWorld(screenToView(uv, depth)));
    float linearDepth = distanceFromCamera / far;

    /* shadow */
    vec4 shadow = getSoftShadow(uv, depth, gbufferProjectionInverse, gbufferModelViewInverse);
    // decrease shadow as it rains
    shadow.a *= rainFactor;
    // decrease shadow with distance
    float shadowBlend = clamp((distanceFromCamera - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
    shadow.a = mix(shadow.a, 0, shadowBlend);

    /* lighting */
    // direct sky light
    vec3 skyDirectLight = max(shadowDirectionDotNormal, 0) * skyLightColor;
    skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
    skyDirectLight = mix(skyDirectLight, shadow.rgb * skyLightColor, shadow.a); // apply shadow
    // ambiant sky light
    vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity;
    // emissive block light
    vec3 blockLight = blockLightColor * blockLightIntensity;
    // perfect diffuse
    vec3 color = albedo * occlusion * (skyDirectLight + ambiantSkyLight + blockLight);

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
/* RENDERTARGETS: 0,1,2,3,4 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueTypeData;
layout(location = 3) out vec4 transparentColorData;
layout(location = 4) out vec4 transparentNormalData;

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
    // indirect sky & block light and type
    vec4 lightAndTypeData_opaque = texture2D(colortex2, uv);
    vec2 lightData_opaque = lightAndTypeData_opaque.xy;
    lightData_opaque = SRGBtoLinear(lightData_opaque);
    float blockLightIntensity_opaque = lightData_opaque.x;
    float ambiantSkyLightIntensity_opaque = lightData_opaque.y;
    float type_opaque = lightAndTypeData_opaque.z;
    // depth
    float depth_opaque = texture2D(depthtex1, uv).x;
    // PBR
    vec4 PBRData_opaque = texture2D(colortex6, uv);

    /* transparent buffers values */
    // albedo
    vec4 albedoData_transparent = texture2D(colortex3, uv);
    albedoData_transparent = SRGBtoLinear(albedoData_transparent);
    vec3 albedo_transparent = albedoData_transparent.rgb;
    float transparency_transparent = albedoData_transparent.a;
    // normal
    vec4 normalData_transparent = texture2D(colortex4, uv);
    vec3 normal_transparent = normalData_transparent.xyz *2 -1;
    // indirect sky & block light and type
    vec4 lightAndTypeData_transparent = texture2D(colortex5, uv);
    vec2 lightData_transparent = lightAndTypeData_transparent.xy;
    lightData_transparent = SRGBtoLinear(lightData_transparent);
    float blockLightIntensity_transparent = lightData_transparent.x;
    float ambiantSkyLightIntensity_transparent = lightData_transparent.y;
    float type_transparent = lightAndTypeData_transparent.z;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;
    // PBR
    vec4 PBRData_transparent = texture2D(colortex7, uv);


    float ambiantFactor_opaque = 0.2;
    float ambiantFactor_transparent = 0.2; // 1


    // -- WRITE STATIC BUFFERS -- //
    opaqueNormalData = normalData_opaque;
    opaqueTypeData = vec4(type_opaque, type_transparent, 0, 1);
    transparentNormalData = normalData_transparent;

    // -- INIT DYNAMIC BUFFERS -- //
    opaqueColorData = vec4(0);
    transparentColorData = vec4(0);



    // view space pos
    vec3 NDCPos = vec3(uv, depth_opaque) * 2.0 - 1.0;
    vec3 viewSpacePosition = projectAndDivide(gbufferProjectionInverse, NDCPos);
    viewSpacePosition = screenToView(uv, depth_opaque);

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
    } 
    // -- LIT MATERIAL -- //
    else if (type_opaque == 1) {
        opaqueColorData += lighting(
            uv, 
            albedo_opaque, 
            transparency_opaque, 
            normal_opaque, 
            depth_opaque,  
            ambiantSkyLightIntensity_opaque, 
            blockLightIntensity_opaque,
            false
        );

        // opaqueColorData = vec4(1,1,0,1);
        // opaqueColorData = PBRData_opaque;
    }

    // -- GLOWING MATERIAL-- //
    if (type_transparent < 1) {
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
            ambiantSkyLightIntensity_transparent, 
            blockLightIntensity_transparent,
            true
        );
        
        // transparentColorData = vec4(0,0,1,1);
        // transparentColorData = PBRData_transparent;
    }

    opaqueColorData = linearToSRGB(opaqueColorData);
    transparentColorData = linearToSRGB(transparentColorData);
}
