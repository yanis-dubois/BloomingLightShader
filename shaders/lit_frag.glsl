#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform float alphaTestRef;
uniform float viewWidth;
uniform float viewHeight;
uniform int moonPhase; // 0=fullmoon, 1=waning gibbous, 2=last quarter, 3=waning crescent, 4=new, 5=waxing crescent, 6=first quarter, 7=waxing gibbous
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec3 viewSpacePosition;
in vec3 normal;
in vec2 textureCoordinate; // immuable block & item 
in vec2 lightMapCoordinate; // light map

const float PI = 3.14159265359;
const float e = 2.71828182846;
const float lambda = 5.5;
const float gamma = 0.1;

// results
/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 outColor0;

float sigmoid(float x, float offset, float speed) {
    return (offset / (offset + pow(e, -speed * x)));
}

float cosThetaToSigmoid(float cosTheta, float offset, float speed) {
    float normalizedAngle = acos(cosTheta)/PI *4 -1;
    return 1 - sigmoid(normalizedAngle, offset, speed);
}

vec3 kelvinToRGB(float kelvin) {
    // Normalize the Kelvin value to fit the range.
    float temperature = kelvin / 100.;

    // Initialize RGB values
    float red, green, blue;

    // Calculate red
    if (temperature <= 66.) {
        red = 1.;
    } else {
        red = temperature - 60.;
        red = 329.698727446 * pow(red, -0.1332047592);
        red = clamp(min(255., red), 0, 255) / 255.;
    }

    // Calculate green
    if (temperature <= 66.) {
        green = temperature;
        green = 99.4708025861 * log(green) - 161.1195681661;
    } else {
        green = temperature - 60.;
        green = 288.1221695283 * pow(green, -0.0755148492);
    }
    green = clamp(min(255., green), 0, 255) / 255.;

    // Calculate blue
    if (temperature >= 66.) {
        blue = 1.;
    } else {
        if (temperature <= 19.) {
            blue = 0.;
        } else {
            blue = temperature - 10.;
            blue = 138.5177312231 * log(blue) - 305.0447927307;
            blue = clamp(min(255., blue), 0, 255) / 255.;
        }
    }

    return vec3(red, green, blue);
}

void main() {

    /* texture value */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    // use original minecraft lightmap 
    // vec3 blockLightValue = pow(texture2D(lightmap, vec2(lightMapCoordinate.x, 1./32.)).rgb, vec3(2.2));
    // vec3 skyIndirectLightValue = pow(texture2D(lightmap, vec2(1./32., lightMapCoordinate.y)).rgb, vec3(2.2));

    float blockLightIntensity = pow(lightMapCoordinate.x, 2.2);
    float ambiantSkyLightIntensity = pow(lightMapCoordinate.y, 2.2);
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2)*1.; // max ???
    float moonPhaseBlend = moonPhase < 4 ? moonPhase*1./4. : (4.-(moonPhase*1.-4.))/4.; 
    moonPhaseBlend = cos(moonPhaseBlend * PI) / 2. + 0.5; // [0;1] new=0, full=1

    /* albedo */
    vec3 albedo = pow(textureColor.rgb, vec3(2.2))
                * pow(additionalColor.rgb, vec3(2.2));
    
    /* transparency */
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;

    // depth 
    float distanceFromCamera = distance(vec3(0), viewSpacePosition);
    float depth = distanceFromCamera / fogEnd;

    // directions in world space
    vec3 upDirection = vec3(0.,1.,0.);
    vec3 normalWorldSpace = mat3(gbufferModelViewInverse) * normal;
    vec3 sunLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * sunPosition);

    // angles 
    float sunDirectionDotNormal = dot(sunLightDirectionWorldSpace, normalWorldSpace);
    float sunDirectionDotUp = dot(sunLightDirectionWorldSpace, upDirection);

    // shadow
    // lot of space conversion to get fragPosition into screen space
    vec3 fragFeetPlayerSpace = (gbufferModelViewInverse * vec4(viewSpacePosition,1.0)).xyz;
    vec3 adjustedFragFeetPlayerSpace = fragFeetPlayerSpace + 0.03 * normalWorldSpace;
    vec3 fragShadowViewSpace = (shadowModelView * vec4(adjustedFragFeetPlayerSpace,1.0)).xyz;
    vec4 fragHomogeneousSpace = shadowProjection * vec4(fragShadowViewSpace,1.0);
    vec3 fragShadowNdcSpace = fragHomogeneousSpace.xyz / fragHomogeneousSpace.w;
    float distanceFromPlayerShadowNdc = length(fragShadowNdcSpace.xy);
    vec3 distortedShadowNdcSpace = vec3(fragShadowNdcSpace.xy / (0.1+distanceFromPlayerShadowNdc), fragShadowNdcSpace.z);
    vec3 fragShadowScreenSpace = distortedShadowNdcSpace * 0.5 + 0.5;
    // is frag in shadow ?
    float isInShadow = step(fragShadowScreenSpace.z, texture2D(shadowtex0, fragShadowScreenSpace.xy).r);
    float isntInColoredShadow = step(fragShadowScreenSpace.z, texture2D(shadowtex1, fragShadowScreenSpace.xy).r);
    vec4 shadowColor = texture2D(shadowcolor0, fragShadowScreenSpace.xy);
    // shadow get colored if needed
    vec3 shadow = vec3(1);
    if (isInShadow == 0) {
        if (isntInColoredShadow == 0) {
            shadow = vec3(0);
        } else {
            shadow = shadowColor.rgb * (1-shadowColor.a);
        }
    }
    // decrease shadow with distance
    float startShadowDecrease = 125;
    float endShadowDecrease = 150;
    float shadowBlend = clamp((distanceFromCamera - startShadowDecrease) / (endShadowDecrease - startShadowDecrease), 0, 1);
    shadow = mix(shadow, vec3(1), shadowBlend);

    // color //
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
    float skyDayNightBlend = sigmoid(sunDirectionDotUp, 1., 50.);
    vec3 rainySkyColor = 0.5 * kelvinToRGB(8000);
    vec3 skyLightColor = mix(moonLightColor, sunLightColor, skyDayNightBlend);
    skyLightColor = mix(skyLightColor, rainySkyColor, rainStrength); // reduce contribution if it rain
    skyLightColor = pow(skyLightColor, vec3(2.2));
    // emissive block color 
    float blockColorTemperature = 5000.;
    vec3 blockLightColor = kelvinToRGB(blockColorTemperature);
    blockLightColor = pow(blockLightColor, vec3(2.2));

    // light //
    // direct sky light
    float rainFactor = max(1-rainStrength, 0.05);
    vec3 skyDirectLight = shadow * skyLightColor * abs(sunDirectionDotNormal);
    skyDirectLight *= rainFactor * abs(skyDayNightBlend-0.5)*2; // reduce contribution as it rains or during day-night transition
    // ambiant sky light
    const float ambiantFactor = 0.2;
    vec3 ambiantSkyLight = ambiantFactor * skyLightColor * ambiantSkyLightIntensity;
    // emissive block light
    vec3 blockLight = blockLightColor * blockLightIntensity;
    // dynamic emissive light 
    vec3 heldBlockLight = blockLightColor * pow(max(1-(distanceFromCamera/(0.0001+heldLightValue)), 0), 2.2);
    // perfect diffuse
    vec3 outColor = albedo * (skyDirectLight + ambiantSkyLight + max(blockLight, heldBlockLight));
    outColor = pow(outColor, vec3(1/2.2));

    // custom fog
    float density = 1.5;
    // exponential square function
    float customFogBlend = 1 - pow(2, -(depth*density)*(depth*density));
    outColor = mix(outColor, fogColor, customFogBlend);

    // vanilla fog
    float minVanillaFogDistance = fogStart;
    float maxVanillaFogDistance = fogEnd;
    float vanillaFogBlend = clamp((distanceFromCamera - minVanillaFogDistance) / (maxVanillaFogDistance - minVanillaFogDistance), 0, 1);
    outColor = mix(outColor, fogColor, vanillaFogBlend);

    // combine color & transparency as result
    outColor0 = vec4(outColor, transparency);

    /** debug **/
    // outColor0 = vec4((blockLight), 1);
    // shadow map
    // outColor0 = vec4(texture2D(shadowtex0, gl_FragCoord.xy/vec2(viewWidth,viewHeight)).rgb, 1);
}
