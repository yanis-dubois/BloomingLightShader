//////////////////////////
//////// Textures ////////
//////////////////////////

// format
/*
const int colortex0Format = RGBA16F; // opaque color
const int colortex1Format = RGBA16F; // opaque normal
const int colortex2Format = RGBA8; // opaque light
const int colortex3Format = RGBA8; // opaque material
const int colortex4Format = RGBA16F; // transparent color
const int colortex5Format = RGBA16F; // transparent normal
const int colortex6Format = RGBA8; // transparent light
const int colortex7Format = RGBA8; // transparent material
*/

const bool colortex0Clear = true;
const bool colortex1Clear = true;
const bool colortex2Clear = true;
const bool colortex3Clear = true;
const bool colortex4Clear = true;
const bool colortex5Clear = true;
const bool colortex6Clear = true;
const bool colortex7Clear = true;

// resolution
// const int noiseTextureResolution = 256;
const int shadowMapResolution = 2048; // 1024 1536 2048

//////////////////////////
/////// Parameters ///////
//////////////////////////

// sun and moon
const float sunPathRotation = 0;
#define SKY_LIGHT_COLOR 1 // 0=constant 1=tweaked
#define BLOCK_LIGHT_COLOR 1 // 0=constant 1=tweaked

// fog
#define FOG_TYPE 2 // 0=off 1=vanilla 2=custom

// shadows
#define SHADOW_TYPE 1 // 0=off 1=stochastic 2=classic
#define SHADOW_KERNEL 1 // 0=box 1=gaussian
#define SHADOW_RANGE 1 // width of the sample area
#define SHADOW_RESOLUTION 4 // half number of samples

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;
const float startShadowDecrease = 100;
const float endShadowDecrease = 150;

// Screen Space Reflection (SSR)
#define SSR_TYPE 0 // 0=off 1=only_fresnel 2=SSR
#define SSR_RESOLUTION 0.1 // from 0=low to 1=high
#define SSR_STEPS 10 // from 0=none to inf=too_much
#define SSR_THICKNESS 0.5 // from 0=too_precise to inf=awful

// animation
#define VERTEX_ANIMATION 2 // 0=off 1=only_vertex 2=vertex_and_normal
#define SHADOW_WATER_ANIMATION 1 // 0=off 1=on
#define LIGHT_EMISSION_ANIMATION 1 // 0=off 1=on

// subsurface scattering
#define SUBSURFACE_TYPE 1 // 0=off 1=on

// light shaft
#define VOLUMETRIC_LIGHT_TYPE 1 // 0=off 1=on
#define VOLUMETRIC_LIGHT_RESOLUTION 0.5 // in [0;inf] 0.5=one_sample_each_two_block 1=one_sample_per_block 2=two_sample_per_block
#define VOLUMETRIC_LIGHT_MIN_SAMPLE 8
#define VOLUMETRIC_LIGHT_MAX_SAMPLE 16
#define VOLUMETRIC_LIGHT_INTENSITY 1

// bloom
#define BLOOM_TYPE 3 // 0=off 1=stochastic 2=classic 3=classic_optimized
#define BLOOM_KERNEL 1 // 0=box 1=gaussian
#define BLOOM_STD 0.4
#define BLOOM_RANGE 8 // extent of the kernel
#define BLOOM_RESOLTUION 0.5 // range * resolution = half number of samples 
#define BLOOM_FACTOR 0.5 // from 0=none to 1=too_much

//////////////////////////
//////// Uniforms ////////
//////////////////////////

const float typeBasic = 0.0;
const float typeParticle = 0.33;
const float typeWater = 0.66;
const float typeLit = 1.0;

// uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec4 entityColor;

uniform vec3 eyePosition;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float shadowAngle;
uniform float sunAngle;
uniform float rainfall;
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

uniform int frameCounter; // in [0;720719]
uniform int worldTime; // in tick [0;23999]
uniform int moonPhase; // 0=fullmoon, 1=waning gibbous, 2=last quarter, 3=waning crescent, 4=new, 5=waxing crescent, 6=first quarter, 7=waxing gibbous
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int isEyeInWater;
