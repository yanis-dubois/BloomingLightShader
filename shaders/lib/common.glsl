////////////////////////////////////////////////////
///////////////////// textures /////////////////////
////////////////////////////////////////////////////

// -- setup buffers -- //
// format
/*
const int colortex0Format = RGBA16F; // color
const int colortex1Format = RGB16F; // normal - bloom
const int colortex2Format = RGBA8; // light & material - depth of field mask
const int colortex3Format = RGB16F; // TAA - last frame color
const int colortex4Format = R32F; // TAA - last frame depth
*/
const bool colortex0Clear = true;
const bool colortex1Clear = true;
const bool colortex2Clear = true;
const bool colortex3Clear = false;
const bool colortex4Clear = false;

// -- setup shadow map -- //

const bool shadowHardwareFiltering = true;
const int shadowMapResolution = 1024; // 1024 1536 2048
const float startShadowDecrease = 100;
const float endShadowDecrease = 150;

////////////////////////////////////////////////////
//////////////////// parameters ////////////////////
////////////////////////////////////////////////////

// sky
const float sunPathRotation = 0.0;
#define SKY_TYPE 1 // 0=vanilla 1=custom

// light
#define SKY_LIGHT_COLOR 1 // 0=constant 1=tweaked
#define BLOCK_LIGHT_COLOR 1 // 0=constant 1=tweaked
#define SPLIT_TONING 1 // 0=off 1=on (give a blueish tint to shadows)

// fog
#define FOG_TYPE 2 // 0=off 1=vanilla 2=custom

// shadows
#define SHADOW_TYPE 1 // 0=off 1=stochastic 2=classic+rotation 3=classic
#define SHADOW_RANGE 0.66 // width of the sample area (in uv)
#define SHADOW_SAMPLES 4 // number of samples (for stochastic)
#define SHADOW_KERNEL 0 // 0=box 1=gaussian

// Screen Space Reflection (SSR)
#define SSR_TYPE 0 // 0=off 1=only_fresnel 2=SSR
#define SSR_RESOLUTION 1 // from 0=low to 1=high
#define SSR_STEPS 10 // from 0=none to inf=too_much
#define SSR_THICKNESS 5 // from 0=too_precise to inf=awful

// animation
#define VERTEX_ANIMATION 2 // 0=off 1=only_vertex 2=vertex_and_normal
#define SHADOW_WATER_ANIMATION 1 // 0=off 1=on
#define LIGHT_EMISSION_ANIMATION 1 // 0=off 1=on

// subsurface scattering
#define SUBSURFACE_TYPE 1 // 0=off 1=on

// light shaft
#define VOLUMETRIC_LIGHT_TYPE 1 // 0=off 1=on
#define VOLUMETRIC_LIGHT_RESOLUTION 1.5 // in [0;inf] 0.5=one_sample_each_two_block 1=one_sample_per_block 2=two_sample_per_block
#define VOLUMETRIC_LIGHT_MIN_SAMPLE 4
#define VOLUMETRIC_LIGHT_MAX_SAMPLE 8
#define VOLUMETRIC_LIGHT_INTENSITY 1

// bloom
#define BLOOM_TYPE 2 // 0=off 1=old_school 2=ULTRA
#define BLOOM_RANGE 0.015 // extent of the kernel
#define BLOOM_RESOLUTION 0.5 // in [0;1], proportion of pixel to be sampled
#define BLOOM_KERNEL 1 // 0=box 1=gaussian
#define BLOOM_STD 0.5 // standard deviation (only for gaussian kernel)
#define BLOOM_FACTOR 2.0 // from 0=none to 1=too_much

// depth of field
#define DOF_TYPE 0 // 0=off 1=dynamic_focus 2=static_focus
#define DOF_RANGE 0.005 // extent of the kernel
#define DOF_RESOLUTION 1 // in [0;1], proportion of pixel to be sampled
#define DOF_KERNEL 0 // 0=box 1=gaussian
#define DOF_STD 0.5 // standard deviation (only for gaussian kernel)
#define DOF_FOCAL_PLANE_LENGTH 20 // half length in blocks

// TAA
#define TAA_TYPE 2 // 0=off 1=soft[denoise] 2=hard[denoise & anti aliasing]

// distortion
#define DISTORTION_WATER_REFRACTION 1 // 0=off 1=on

// quantization
#define QUANTIZATION_TYPE 0 // 0=off 1=on 2=dithered
#define QUANTIZATION_AMOUNT 1.0 // number of color used

// chromatic aberation
#define CHROMATIC_ABERATION_TYPE 0 // 0=off 1=on
#define CHROMATIC_ABERATION_AMPLITUDE 0.02 // 0=off 0.02=too_much

////////////////////////////////////////////////////
///////////////////// uniforms /////////////////////
////////////////////////////////////////////////////

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec4 entityColor;

uniform vec3 eyePosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 playerLookVector;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float shadowAngle;
uniform float sunAngle; // 0 is sunrise, 0.25 is noon, 0.5 is sunset, 0.75 is midnight
uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform float alphaTestRef;
uniform float near;
uniform float far;
uniform float viewHeight;
uniform float viewWidth;
uniform float gamma;
uniform float frameTimeCounter;
uniform float ambientLight;

uniform int blockEntityId;
uniform int frameCounter; // in [0;720719]
uniform int worldTime; // in tick [0;23999]
uniform int moonPhase; // 0=fullmoon, 1=waning gibbous, 2=last quarter, 3=waning crescent, 4=new, 5=waxing crescent, 6=first quarter, 7=waxing gibbous
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int isEyeInWater;

////////////////////////////////////////////////////
///////////////// custom uniforms //////////////////
////////////////////////////////////////////////////

uniform float framemod8;

///////////////////////////////////////////////////
//////////////////// constants ////////////////////
///////////////////////////////////////////////////

const vec3 eastDirection = vec3(1.0, 0.0, 0.0);
const vec3 westDirection = vec3(-1.0, 0.0, 0.0);
const vec3 upDirection = vec3(0.0, 1.0, 0.0);
const vec3 downDirection = vec3(0.0, -1.0, 0.0);
const vec3 northDirection = vec3(0.0, 0.0, -1.0);
const vec3 southDirection = vec3(0.0, 0.0, 1.0);

const float PI = 3.14159265359;
const float e = 2.71828182846;
