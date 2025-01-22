#version 140
#extension GL_ARB_explicit_attrib_location : enable

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
in float rainFactor;
in float fog_density;

in vec2 uv;

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"
#include "/lib/animation.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"

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
            out vec4 colorData, out vec4 normalData, out vec4 lightData, out vec4 materialData, out float depth, bool isTransparent) {

    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(albedoTexture, uv);
    vec3 albedo = vec3(0); float transparency = 0;
    getColorData(colorData, albedo, transparency);
    //if (transparency<0.01) return;
    // normal
    normalData = texture2D(normalTexture, uv);
    vec3 normal = vec3(0);
    getNormalData(normalData, normal);
    // light
    lightData = texture2D(lightTexture, uv);
    float blockLightIntensity = 0, ambientSkyLightIntensity = 0, emissivness = 0, ambient_occlusion = 0;
    getLightData(lightData, blockLightIntensity, ambientSkyLightIntensity, emissivness, ambient_occlusion);
    // material
    materialData = texture2D(materialTexture, uv);
    float type = 0, smoothness = 0, reflectance = 0, subsurface = 0;
    getMaterialData(materialData, type, smoothness, reflectance, subsurface);
    // depth
    vec4 depthData = texture2D(depthTexture, uv);
    depth = 0;
    getDepthData(depthData, depth);

    // -- light computation -- //
    // basic or glowing
    if (isBasic(type)) {
        // glowing
        if (isTransparent && getLightness(albedo) > 0.01) {
            // apply fog
            vec3 worldSpacePosition = screenToWorld(uv, depth);
            float normalizedLinearDepth = distance(cameraPosition, worldSpacePosition) / far;
            albedo = foggify(albedo, worldSpacePosition, normalizedLinearDepth);

            // write in opaque buffer
            opaqueColorData.rgb = linearToSRGB(albedo);
            opaqueLightData.z = 1; // add emissivness
        }
        // sky
        else if (!isTransparent) {
            // write value as it is
            colorData = vec4(albedo, transparency);

            // foggify if camera in water
            if (isEyeInWater==1) {
                vec3 worldSpacePosition = screenToWorld(uv, depth);
                float normalizedLinearDepth = distance(cameraPosition, worldSpacePosition) / far;
                colorData.rgb = foggify(colorData.rgb, worldSpacePosition, normalizedLinearDepth);
            }
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
            ambientSkyLightIntensity, 
            blockLightIntensity,
            emissivness,
            ambient_occlusion,
            isTransparent
        );
    }
}

/*****************************************
************* lighting & fog *************
******************************************/
void main() {
    float depthAll=0, depthOpaque=0;
    process(colortex0, colortex1, colortex2, colortex3, depthtex1, opaqueColorData, opaqueNormalData, opaqueLightData, opaqueMaterialData, depthOpaque, false);
    process(colortex4, colortex5, colortex6, colortex7, depthtex0, transparentColorData, transparentNormalData, transparentLightData, transparentMaterialData, depthAll, true); 

    // -- volumetric light -- //
    if (VOLUMETRIC_LIGHT_TYPE > 0) {
        volumetricLighting(uv, depthAll, depthOpaque, min(opaqueLightData.y, transparentLightData.y), isWater(transparentMaterialData.x), opaqueColorData, transparentColorData);
    }

    // convert back to SRGB
    opaqueColorData.rgb = linearToSRGB(opaqueColorData.rgb);
    transparentColorData.rgb = linearToSRGB(transparentColorData.rgb);
}
