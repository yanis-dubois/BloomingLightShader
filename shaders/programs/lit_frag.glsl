#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"
#include "/lib/animation.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules albedo
in vec3 normal;
in vec3 unanimatedWorldPosition;
in vec3 midBlock;
in vec3 worldSpacePosition;
in vec2 textureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
flat in int id;

// results
/* RENDERTARGETS: 0,1,2,3,4,5,6,7 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueNormalData;
layout(location = 2) out vec4 opaqueLightData;
layout(location = 3) out vec4 opaqueMaterialData;
layout(location = 4) out vec4 transparentAlbedoData;
layout(location = 5) out vec4 transparentNormalData;
layout(location = 6) out vec4 transparentLightData;
layout(location = 7) out vec4 transparentMaterialData;

void getMaterialData(int id, inout vec3 albedo, out float smoothness, out float reflectance, out float emissivness, out float ambient_occlusion) {
    smoothness = 0;
    reflectance = 0;
    emissivness = 0;
    ambient_occlusion = 0;

    float n1 = isEyeInWater == 1 ? 1.33 : 1;

    // -- smoothness -- //
    // water
    if (id == 20000) {
        smoothness = 0.4; // 0.9

        ambient_occlusion = 1;

        float n2 = isEyeInWater == 0 ? 1.33 : 1;
        reflectance = getReflectance(n1, n2);
    }
    // glass 
    else if (id == 20010 || id == 20011 || id == 20012 || id == 20013 || id == 20014) {
        smoothness = 0.95;
        ambient_occlusion = 1;
        reflectance = getReflectance(n1, 1.5);
    }
    // metal
    else if (id == 20020) {
        smoothness = 0.75;
        reflectance = getReflectance(n1, 3);
    }
    // polished
    else if (id == 20030 || id == 20031) {
        smoothness = 0.6;
        reflectance = getReflectance(n1, 1.4);
    }
    // specular
    else if (id == 20040) {
        // grass block
        smoothness = 0.4;
        reflectance = getReflectance(n1, 1.3);
    }
    // rough
    else if (id == 20050) {
        smoothness = 0.2;
        reflectance = getReflectance(n1, 1);
    }
    // emmissive and smooth
    else if (id == 30030) {
        smoothness = 0.95;
        reflectance = getReflectance(n1, 1.5);
    }

    // -- emmissive -- //
    if (id >= 30000) {
        if (id < 30040) {
            emissivness = getLightness(albedo);
        }
        else if (id == 30040 || id == 31000) {
            emissivness = 1;
            albedo *= 1.5;
        }
    }

    // -- subsurface & ao -- //
    if (10000 <= id && id < 20000) {
        // leaves
        if (hasNoAmbiantOcclusion(id)) {
            ambient_occlusion = 1;

            smoothness = 0.45;
            reflectance = getReflectance(n1, 1.5);
        }
        // flowers
        else if (isThin(id)) {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(0, objectSpacePosition.y);
            ambient_occlusion = min(ambient_occlusion, 1);
        }
        // sugar cane
        else if (isColumnSubsurface(id)) {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(vec2(0), objectSpacePosition.xz);
            ambient_occlusion = min(ambient_occlusion*5, 1);
        }
        // other foliage
        else {
            vec3 objectSpacePosition = midBlockToRoot(id, midBlock);
            ambient_occlusion = distance(vec3(0), objectSpacePosition);
        }
    }
}

// end portal texture colors
vec3[7] endPortalColors = vec3[](
    vec3(0.098, 0.196, 0.255), // dark cyan
    vec3(0.118, 0.235, 0.275), // greenish dark cyan
    vec3(0.075, 0.196, 0.153)*1.5, // dark green
    vec3(0.196, 0.118, 0.392), // dark blue purple
    vec3(0.075, 0.196, 0.153), // dark green
    vec3(0.157, 0.220, 0.333), // dark blue
    vec3(0.075, 0.196, 0.153)*2  // dark green
);

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    float transparency = textureColor.a;
    // tweak transparency
    if (id == 20010) transparency = clamp(transparency, 0.2, 0.75); // uncolored glass 0.36
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;
    // apply red flash when mob are hitted
    albedo = mix(albedo, entityColor.rgb, entityColor.a); 

    #ifdef TERRAIN
        // end portal & end gates
        if (id == 31000) {
            albedo = vec3(0);
            vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
            float speed = frameTimeCounter * 0.005;

            screenPos *= 0.75;
            vec3 bloup = vec3(0.098, 0.196, 0.255);

            for (int i=0; i<8; ++i) {
                for (int j=0; j<3; ++j) {
                    float angle = j * PI/3 + i * PI/8;
                    float Cos = cos(angle);
                    float Sin = sin(angle);
                    mat2 rotation = mat2(Cos, Sin, -Sin, Cos);

                    vec2 uv = mod(rotation * screenPos.xy + speed, 1);
                    vec3 portalColor = texture2D(gtexture, uv).rgb * normalize(endPortalColors[(i+j) % 7]) * 0.8;
                    portalColor *= map(1 - (float(i) / 8.0), 0, 1, 0.33, 1);
                    albedo += portalColor * length(portalColor);
                }

                screenPos *= 1.4;
            }

            albedo *= bloup;
            albedo = mix(albedo*2, bloup, length(albedo));
            albedo += bloup*0.08;
        }
    #endif

    /* normal */
    vec3 encodedNormal = encodeNormal(normal);
    #ifdef PARTICLE 
        encodedNormal = encodeNormal(-normalize(playerLookVector));
    #endif
    
    /* light */
    float distanceFromEye = distance(eyePosition, worldSpacePosition);
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2);
    float heldBlockLight = heldLightValue>=1 ? max(1 - (distanceFromEye / max(heldLightValue, 1)), 0) : 0;
    float blockLightIntensity = max( (lightMapCoordinate.x), heldBlockLight);
    float ambiantSkyLightIntensity = lightMapCoordinate.y;

    /* material data */
    float smoothness = 0, reflectance = 0, emissivness = 0, ambient_occlusion = 0;
    getMaterialData(id, albedo, smoothness, reflectance, emissivness, ambient_occlusion);
    ambient_occlusion = map(1 - ambient_occlusion, 0.0, 1.0, 0.5, 1.0);

    // generate normalmap if animated
    if (VERTEX_ANIMATION==2 && isAnimated(id) && smoothness>alphaTestRef) {
        mat3 TBN = generateTBN(normal);
        vec3 tangent = TBN[0] / 16.0;
        vec3 bitangent = TBN[1] / 16.0;

        vec3 actualPosition = doAnimation(id, frameTimeCounter, unanimatedWorldPosition, midBlock);
        vec3 tangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + tangent, midBlock);
        vec3 bitangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + bitangent, midBlock);

        vec3 newTangent = normalize(tangentDerivative - actualPosition);
        vec3 newBitangent = normalize(bitangentDerivative - actualPosition);

        vec3 newNormal = normalize(- cross(newTangent, newBitangent));
        if (dot(newNormal, normal) < 0) newNormal *= -1;

        vec3 viewDirection = normalize(cameraPosition - actualPosition);
        if (dot(viewDirection, newNormal) < 0) newNormal = normal;

        encodedNormal = encodeNormal(newNormal);
    }

    /* type */
    float type = typeLit;
    #ifdef TRANSPARENT
        if (id == 20000) type = typeWater;
    #endif
    #ifdef PARTICLE
        type = typeParticle;

        // is glowing particle ?
        bool isGray = (albedo.r - albedo.g)*(albedo.r - albedo.g) + (albedo.r - albedo.b)*(albedo.r - albedo.b) + (albedo.b - albedo.g)*(albedo.b - albedo.g) < 0.05;
        bool isUnderwaterParticle = (albedo.r == albedo.g && albedo.r - 0.5 * albedo.b < 0.06);
        bool isWaterParticle = (albedo.b > 1.15 * (albedo.r + albedo.g) && albedo.g > albedo.r * 1.25 && albedo.g < 0.425 && albedo.b > 0.75);
        if (getLightness(textureColor.rgb) > 0.8 && !isGray && !isWaterParticle && !isUnderwaterParticle) {
            ambient_occlusion = 1;
            emissivness = 1;
            albedo *= 1.5;
        }
    #endif

    // weather smooth transition
    #ifdef WEATHER
        type = typeParticle;
        transparency *= rainStrength;
    #endif

    // light animation
    if (LIGHT_EMISSION_ANIMATION == 1 && emissivness > 0) {
        float noise = doLightAnimation(id, frameTimeCounter, unanimatedWorldPosition);
        emissivness -= noise;
    }

    /* buffers */
    #ifdef TRANSPARENT
        transparentAlbedoData = vec4(albedo, transparency);
        transparentNormalData = vec4(encodedNormal, 1);
        transparentLightData = vec4(blockLightIntensity, ambiantSkyLightIntensity, emissivness, 1);
        transparentMaterialData = vec4(type, smoothness, reflectance, 1);
    #else
        opaqueAlbedoData = vec4(albedo, transparency);
        opaqueNormalData = vec4(encodedNormal, 1);
        opaqueLightData = vec4(blockLightIntensity, ambiantSkyLightIntensity, emissivness, ambient_occlusion);
        opaqueMaterialData = vec4(type, smoothness, reflectance, 1);
    #endif
}
