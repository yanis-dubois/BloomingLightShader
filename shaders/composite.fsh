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
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth

// attributes
in vec2 uv;

// functions
float linearizeDepth(float depth) {
    return 2.05 * (near * far) / (depth * (near - far) + far);
}

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

// results
/* RENDERTARGETS: 0,1,2,3,4 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueTypeData;
layout(location = 3) out vec4 transparentColorData;
layout(location = 4) out vec4 transparentNormalData;

/******************************************
************ lighting SSAO fog ************
*******************************************/
void main() {

    /* opaque buffers values */
    // albedo
    vec4 albedoData_opaque = texture2D(colortex0, uv);
    vec3 albedo_opaque = pow(albedoData_opaque.rgb, vec3(2.2));
    float transparency_opaque = albedoData_opaque.a;
    // normal
    vec4 normalData_opaque = texture2D(colortex1, uv);
    vec3 normal_opaque = normalData_opaque.xyz *2 -1;
    // indirect sky & block light and type
    vec3 lightAndTypeData_opaque = texture2D(colortex2, uv).xyz;
    vec2 lightData_opaque = pow(lightAndTypeData_opaque.xy, vec2(2.2));
    float blockLightIntensity_opaque = lightData_opaque.x;
    float ambiantSkyLightIntensity_opaque = lightData_opaque.y;
    float type_opaque = lightAndTypeData_opaque.z;
    // depth
    float depth_opaque = texture2D(depthtex1, uv).x;
    float distanceFromCamera_opaque = linearizeDepth(depth_opaque);
    float linearDepth_opaque = distanceFromCamera_opaque / far;

    /* transparent buffers values */
    // albedo
    vec4 albedoData_transparent = texture2D(colortex3, uv);
    vec3 albedo_transparent = pow(albedoData_transparent.rgb, vec3(2.2));
    float transparency_transparent = albedoData_transparent.a;
    // normal
    vec4 normalData_transparent = texture2D(colortex4, uv);
    vec3 normal_transparent = normalData_transparent.xyz *2 -1;
    // indirect sky & block light and type
    vec2 lightData_transparent = pow(texture2D(colortex5, uv).xy, vec2(2.2));
    float blockLightIntensity_transparent = lightData_transparent.x;
    float ambiantSkyLightIntensity_transparent = lightData_transparent.y;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;
    float distanceFromCamera_all = linearizeDepth(depth_all);
    float linearDepth_all = distanceFromCamera_all / far;


    // -- WRITE STATIC BUFFERS -- //
    opaqueNormalData = normalData_opaque;
    opaqueTypeData = vec4(type_opaque, 0, 0, 1);
    transparentNormalData = normalData_transparent;


    // -- BASIC MATERIAL -- //
    if (type_opaque == 0) {
        opaqueColorData = vec4(albedo_opaque, transparency_opaque);
    }


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

    /* uniform infos */
    // moon phase
    float moonPhaseBlend = moonPhase < 4 ? moonPhase*1./4. : (4.-(moonPhase*1.-4.))/4.; 
    moonPhaseBlend = cos(moonPhaseBlend * PI) / 2. + 0.5; // [0;1] new=0, full=1
    // day time
    vec3 upDirection = vec3(0,1,0);
    vec3 sunLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunDirectionDotUp = dot(sunLightDirectionWorldSpace, upDirection);
    vec3 shadowLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    /* light colors */
    // sun color
    float sunDawnColorTemperature = 2000.;
    float sunZenithColorTemperature = 6000.;
    float sunColorTemperature = clamp(cosThetaToSigmoid(sunDirectionDotUp, 0.1, 5.5) * (sunZenithColorTemperature-sunDawnColorTemperature) + sunDawnColorTemperature, 
                                        sunDawnColorTemperature, 
                                        sunZenithColorTemperature); // [2000;7000] depending at sun angle
    vec3 sunLightColor = kelvinToRGB(sunColorTemperature); 
    // moon color
    float moonDawnColorTemperature = 20000.;
    float moonFullMidnightColorTemperature = 7500.;
    float moonNewMidnightColorTemperature = 20000.;
    float moonMidnightColorTemperature = clamp(moonPhaseBlend * (moonFullMidnightColorTemperature-moonNewMidnightColorTemperature) + moonNewMidnightColorTemperature, 
                                        moonFullMidnightColorTemperature, 
                                        moonNewMidnightColorTemperature); // taking moon phase account
    float moonColorTemperature = clamp(cosThetaToSigmoid(abs(sunDirectionDotUp), 5., 5.5) * (moonMidnightColorTemperature-moonDawnColorTemperature) + moonDawnColorTemperature, 
                                        moonMidnightColorTemperature, 
                                        moonDawnColorTemperature);
    vec3 moonLightColor = 0.5 * kelvinToRGB(moonColorTemperature); 
    // sky color 
    vec3 rainySkyColor = 0.9 * kelvinToRGB(8000);
    float skyDayNightBlend = sigmoid(sunDirectionDotUp, 1., 50.);
    vec3 skyLightColor = mix(moonLightColor, sunLightColor, skyDayNightBlend);
    skyLightColor = mix(skyLightColor, rainySkyColor, rainStrength); // reduce contribution if it rain
    skyLightColor = pow(skyLightColor, vec3(2.2));
    // emissive block color 
    float blockColorTemperature = 5000.;
    vec3 blockLightColor = kelvinToRGB(blockColorTemperature);
    blockLightColor = pow(blockLightColor, vec3(2.2));
    // fog
    float rainFactor = max(1-rainStrength, 0.05);
    vec3 fog_color = pow(fogColor, vec3(2.2));
    float density = mix(2.5, 1, rainFactor);

    // init albedo 
    vec3 outColor_opaque = vec3(0);
    vec3 outColor_transparent = vec3(0);

    // -- LIT MATERIAL -- //
    if (type_opaque == 1) {
        // directions and angles
        float shadowDirectionDotNormal = dot(shadowLightDirectionWorldSpace, normal_opaque);

        /* shadow */
        vec3 shadow = getSoftShadow(uv, depth_opaque, gbufferProjectionInverse, gbufferModelViewInverse);
        // decrease shadow with distance
        float startShadowDecrease = 200;
        float endShadowDecrease = 250;
        float shadowBlend = clamp((distanceFromCamera_opaque - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
        shadow = mix(shadow, vec3(1), shadowBlend);

        /* lighting */
        // direct sky light
        vec3 skyDirectLight = shadow * max(shadowDirectionDotNormal, 0) * skyLightColor;
        skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
        // ambiant sky light
        float ambiantFactor = 0.2;
        vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity_opaque;
        // emissive block light
        vec3 blockLight = blockLightColor * blockLightIntensity_opaque;
        // perfect diffuse
        outColor_opaque = albedo_opaque * occlusion * (skyDirectLight + ambiantSkyLight + blockLight);
        outColor_opaque = outColor_opaque;

        /* fog */
        // custom fog
        float customFogBlend = clamp(1 - pow(2, -(linearDepth_opaque*density)*(linearDepth_opaque*density)*(linearDepth_opaque*density)), 0, 1); // exponential function
        outColor_opaque = mix(outColor_opaque, fog_color, customFogBlend);
        // vanilla fog
        float vanillaFogBlend = clamp((distanceFromCamera_opaque - fogStart) / (fogEnd - fogStart), 0, 1);
        outColor_opaque = mix(outColor_opaque, fog_color, vanillaFogBlend);

        opaqueColorData = vec4(outColor_opaque, transparency_opaque);
    }

    // -- TRANSPARENT MATERIAL -- //
    if (depth_all<depth_opaque && transparency_transparent>alphaTestRef) {
        // directions and angles
        float shadowDirectionDotNormal = dot(shadowLightDirectionWorldSpace, normal_transparent);

        /* shadow */
        vec3 shadow = getSoftShadow(uv, depth_all, gbufferProjectionInverse, gbufferModelViewInverse);
        // decrease shadow with distance
        float startShadowDecrease = 125;
        float endShadowDecrease = 150;
        float shadowBlend = clamp((distanceFromCamera_all - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
        shadow = mix(shadow, vec3(1), shadowBlend);

        /* lighting */
        // direct sky light
        vec3 skyDirectLight = shadow * max(shadowDirectionDotNormal, 0) * skyLightColor;
        skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
        // ambiant sky light
        float ambiantFactor = 1;
        vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity_transparent;
        // emissive block light
        vec3 blockLight = blockLightColor * blockLightIntensity_transparent;
        // perfect diffuse
        outColor_transparent = albedo_transparent * (skyDirectLight + ambiantSkyLight + blockLight);
        outColor_transparent = outColor_transparent;

        /* fog */
        // custom fog
        float customFogBlend = clamp(1 - pow(2, -(linearDepth_all*density)*(linearDepth_all*density)*(linearDepth_all*density)), 0, 1); // exponential function
        outColor_transparent = mix(outColor_transparent, fog_color, customFogBlend);
        // vanilla fog
        float vanillaFogBlend = clamp((distanceFromCamera_all - fogStart) / (fogEnd - fogStart), 0, 1);
        outColor_transparent = mix(outColor_transparent, fog_color, vanillaFogBlend);

        transparentColorData = vec4(outColor_transparent, transparency_transparent);
    }
    
    /* debug */
    // outColor0 = vec4(vec3(1), 1);
    // shadow map
    // outColor0 = vec4(texture2D(shadowtex0, gl_FragCoord.xy/vec2(viewWidth,viewHeight)).rgb, 1);

    /* /!\ IMPORTANT /!\ */
    // blend opaque & transparent together
    // outColor0 = vec4(vec3(mix(outColor_opaque, outColor_transparent, transparency_transparent)), 1); return;
}
