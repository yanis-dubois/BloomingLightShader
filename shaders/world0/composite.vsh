#version 140

#include "/lib/common.glsl"
#include "/lib/utils.glsl"

out vec3 sunLightColor;
out vec3 moonLightColor;
out vec3 skyLightColor;
out vec3 blockLightColor;
out vec3 fog_color;
out float moonPhaseBlend;
out float skyDayNightBlend;
out float rainFactor;
out float fog_density;

out vec2 uv;

void main() {
    /* uniform infos */

    // moon phase
    moonPhaseBlend = moonPhase < 4 ? moonPhase*1./4. : (4.-(moonPhase*1.-4.))/4.; 
    moonPhaseBlend = cos(moonPhaseBlend * PI) / 2. + 0.5; // [0;1] new=0, full=1

    // day time
    vec3 upDirection = vec3(0,1,0);
    vec3 sunLightDirectionWorldSpace = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunDirectionDotUp = dot(sunLightDirectionWorldSpace, upDirection);
    
    // sun color
    float sunDawnColorTemperature = 2000.;
    float sunZenithColorTemperature = 6000.;
    float sunColorTemperature = clamp(cosThetaToSigmoid(sunDirectionDotUp, 0.00001, 20) * (sunZenithColorTemperature-sunDawnColorTemperature) + sunDawnColorTemperature, 
                                        sunDawnColorTemperature, 
                                        sunZenithColorTemperature); // [2000;7000] depending at sun angle
    sunLightColor = kelvinToRGB(sunColorTemperature); 
    
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
    moonLightColor = 0.5 * kelvinToRGB(moonColorTemperature); 
    
    // sky color 
    vec3 rainySkyColor = 0.9 * kelvinToRGB(8000);
    skyDayNightBlend = sigmoid(sunDirectionDotUp, 1., 50.);
    skyLightColor = mix(moonLightColor, sunLightColor, skyDayNightBlend);
    skyLightColor = mix(skyLightColor, skyLightColor*rainySkyColor, rainStrength); // reduce contribution if it rain
    skyLightColor = pow(skyLightColor, vec3(2.2));

    // emissive block color 
    float blockColorTemperature = 4500.;
    blockLightColor = kelvinToRGB(blockColorTemperature);
    blockLightColor = pow(blockLightColor, vec3(2.2));

    // rain
    rainFactor = max(1-rainStrength, 0.05);

    // fog
    fog_color = pow(fogColor, vec3(2.2));
    fog_density = mix(0.8, 1.5, rainStrength);



    /* vertex infos */
    gl_Position = ftransform();
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
