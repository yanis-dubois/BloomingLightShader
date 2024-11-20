#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/utils.glsl"
#include "/lib/shadow.glsl"

// textures
uniform sampler2D colortex0; // opaque albedo
uniform sampler2D colortex1; // opaque normal
uniform sampler2D colortex2; // opaque light & type : x=block_light, y=sky_ambiant_light, z=material_type[0:basic,0.5:transparent,1:lit]
uniform sampler2D colortex3; // transparent albedo
uniform sampler2D colortex4; // transparent normal
uniform sampler2D colortex5; // transparent light & type
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth
uniform sampler2D shadowtex0; // all shadow
uniform sampler2D shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color

// uniforms
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform float alphaTestRef;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform int moonPhase; // 0=fullmoon, 1=waning gibbous, 2=last quarter, 3=waning crescent, 4=new, 5=waxing crescent, 6=first quarter, 7=waxing gibbous

// attributes
in vec2 uv;

// functions
// say if a pixel is in shadow and apply a shadow color to it if needed
vec3 getShadow(vec3 shadowScreenPos) {
    float isInShadow = step(shadowScreenPos.z, texture2D(shadowtex0, shadowScreenPos.xy).r);
    float isntInColoredShadow = step(shadowScreenPos.z, texture2D(shadowtex1, shadowScreenPos.xy).r);
    vec4 shadowColor = texture2D(shadowcolor0, shadowScreenPos.xy);

    // shadow get colored if needed
    vec3 shadow = vec3(1);
    if (isInShadow == 0) {
        if (isntInColoredShadow == 0) {
            shadow = vec3(0);
        } else {
            shadow = shadowColor.rgb * (1-shadowColor.a);
        }
    }

    return shadow;
}

// blur shadow by calling getShadow around actual pixel and average results
vec3 getSoftShadow(vec2 uv, float depth) {
    const float range = SHADOW_SOFTNESS / 2; // how far away from the original position we take our samples from
    const float increment = range / SHADOW_QUALITY; // distance between each sample
    
    vec3 NDCPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

    vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
    int samples = 0;

    for (float x = -range; x <= range; x += increment) {
        for (float y = -range; y <= range; y += increment) {
            vec2 offset = vec2(x, y) / shadowMapResolution; // we divide by the resolution so our offset is in terms of pixels
            vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
            offsetShadowClipPos.z -= 0.0015; // apply bias
            offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
            vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
            vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
            shadowAccum += getShadow(shadowScreenPos); // take shadow sample
            samples++;
        }
    }
    
    return shadowAccum / float(samples); // divide sum by count, getting average shadow
}

float linearizeDepth(float depth) {
    return 2.05 * (near * far) / (depth * (near - far) + far);
}

// results
/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0;

void main() {

    /* opaque buffers values */
    // albedo
    vec4 albedoData_opaque = texture2D(colortex0, uv);
    vec3 albedo_opaque = pow(albedoData_opaque.rgb, vec3(2.2));
    float transparency_opaque = albedoData_opaque.a;
    // normal
    vec3 normal_opaque = texture2D(colortex1, uv).xyz *2 -1;
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
    vec3 normal_transparent = texture2D(colortex4, uv).xyz *2 -1;
    // indirect sky & block light and type
    vec3 lightAndTypeData_transparent = texture2D(colortex5, uv).xyz;
    vec2 lightData_transparent = pow(lightAndTypeData_transparent.xy, vec2(2.2));
    float blockLightIntensity_transparent = lightData_transparent.x;
    float ambiantSkyLightIntensity_transparent = lightData_transparent.y;
    float type_transparent = lightAndTypeData_transparent.z;
    // depth 
    float depth_all = texture2D(depthtex0, uv).x;
    float distanceFromCamera_all = linearizeDepth(depth_all);
    float linearDepth_all = distanceFromCamera_all / far;

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

    // outColor0 = vec4(vec3(albedo_opaque), 1); return;

    // init albedo 
    vec3 outColor_opaque = vec3(0);
    vec3 outColor_transparent = vec3(0);

    // basic material
    if (type_opaque == 0) {
        outColor_opaque = pow(albedo_opaque, vec3(1/2.2));
    }
    // lit material
    else {
        // directions and angles
        float shadowDirectionDotNormal = dot(shadowLightDirectionWorldSpace, normal_opaque);

        /* shadow */
        vec3 shadow = getSoftShadow(uv, depth_opaque);
        // decrease shadow with distance
        float startShadowDecrease = 125;
        float endShadowDecrease = 150;
        float shadowBlend = clamp((distanceFromCamera_opaque - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
        shadow = mix(shadow, vec3(1), shadowBlend);

        /* lighting */
        // direct sky light
        float rainFactor = max(1-rainStrength, 0.05);
        vec3 skyDirectLight = shadow * max(shadowDirectionDotNormal, 0) * skyLightColor;
        skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
        // ambiant sky light
        float ambiantFactor = 0.2;
        vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity_opaque;
        // emissive block light
        vec3 blockLight = blockLightColor * blockLightIntensity_opaque;
        // perfect diffuse
        outColor_opaque = albedo_opaque * (skyDirectLight + ambiantSkyLight + blockLight);
        outColor_opaque = pow(outColor_opaque, vec3(1/2.2));

        /* fog */
        // custom fog
        float density = mix(2.5, 1.5, rainFactor);
        float customFogBlend = clamp(1 - pow(2, -(linearDepth_opaque*density)*(linearDepth_opaque*density)*(linearDepth_opaque*density)), 0, 1); // exponential function
        outColor_opaque = mix(outColor_opaque, fogColor, customFogBlend);
        // vanilla fog
        float vanillaFogBlend = clamp((distanceFromCamera_opaque - fogStart) / (fogEnd - fogStart), 0, 1);
        outColor_opaque = mix(outColor_opaque, fogColor, vanillaFogBlend);
    }

    // transparent material (avoid invisible pixels)
    if (depth_all<depth_opaque && transparency_transparent>alphaTestRef) {
        // directions and angles
        float shadowDirectionDotNormal = dot(shadowLightDirectionWorldSpace, normal_transparent);

        /* shadow */
        vec3 shadow = getSoftShadow(uv, depth_all);
        // decrease shadow with distance
        float startShadowDecrease = 125;
        float endShadowDecrease = 150;
        float shadowBlend = clamp((distanceFromCamera_all - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
        shadow = mix(shadow, vec3(1), shadowBlend);

        /* lighting */
        // direct sky light
        float rainFactor = max(1-rainStrength, 0.05);
        vec3 skyDirectLight = shadow * max(shadowDirectionDotNormal, 0) * skyLightColor;
        skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
        // ambiant sky light
        float ambiantFactor = 1;
        vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity_transparent;
        // emissive block light
        vec3 blockLight = blockLightColor * blockLightIntensity_transparent;
        // perfect diffuse
        outColor_transparent = albedo_transparent * (skyDirectLight + ambiantSkyLight + blockLight);
        outColor_transparent = pow(outColor_transparent, vec3(1/2.2));

        /* fog */
        // custom fog
        float density = mix(2.5, 1.5, rainFactor);
        float customFogBlend = clamp(1 - pow(2, -(linearDepth_all*density)*(linearDepth_all*density)*(linearDepth_all*density)), 0, 1); // exponential function
        outColor_transparent = mix(outColor_transparent, fogColor, customFogBlend);
        // vanilla fog
        float vanillaFogBlend = clamp((distanceFromCamera_all - fogStart) / (fogEnd - fogStart), 0, 1);
        outColor_transparent = mix(outColor_transparent, fogColor, vanillaFogBlend);
    }

    /* result */
    // outColor0 = vec4(outColor_opaque, transparency_opaque);
    // outColor0 = vec4(outColor_transparent, transparency_transparent);

    /* debug */
    // outColor0 = vec4(vec3(outColor0), 1);
    // shadow map
    // outColor0 = vec4(texture2D(shadowtex0, gl_FragCoord.xy/vec2(viewWidth,viewHeight)).rgb, 1);

    /* /!\ IMPORTANT /!\ */
    // blend opaque & transparent together
    outColor0 = vec4(vec3(mix(outColor_opaque, outColor_transparent, albedoData_transparent.a)), 1); return;
}
