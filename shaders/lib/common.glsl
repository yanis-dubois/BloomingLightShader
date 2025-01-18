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

// resolution
// const int noiseTextureResolution = 256;
const int shadowMapResolution = 2048; // 2048

//////////////////////////
/////// Parameters ///////
//////////////////////////

// sun and moon
const float sunPathRotation = 0;
#define SKY_LIGHT_COLOR 1 // 0=off 1=on

// fog
#define FOG_TYPE 2 // 0=off 1=vanilla 2=custom

// shadows
#define SHADOW_TYPE 1 // 0=off 1=stochastic 2=classic
#define SHADOW_QUALITY 5 // half number of samples
#define SHADOW_SOFTNESS 2.0 // width of the sample area

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;
const float startShadowDecrease = 100;
const float endShadowDecrease = 150;

// Screen Space Ambiant Occlusion (SSAO)
#define SSAO_SAMPLES 0 // number of samples
#define SSAO_RADIUS 1
#define SSAO_BIAS 0
#define SSAO_MAGNITUDE 1.5
#define SSAO_CONTRAST 1.5

// Screen Space Reflection (SSR)
#define SSR_TYPE 2 // 0=off 1=only_fresnel 2=SSR
#define SSR_RESOLUTION 0.1 // from 0=low to 1=high
#define SSR_STEPS 10 // from 0=none to inf=too_much
#define SSR_THICKNESS 0.5 // from 0=too_precise to inf=awful

// animation
#define ANIMATION_TYPE 2 // 0=off 1=only_vertex 2=vertex_and_normal

// subsurface scattering
#define SUBSURFACE_TYPE 1 // 0=off 1=on

// light shaft
#define VOLUMETRIC_LIGHT_TYPE 1 // 0=off 1=on
#define VOLUMETRIC_LIGHT_RESOLUTION 1 // in [0;inf] 0.5=one_sample_each_two_block 1=one_sample_per_block 2=two_sample_per_block

// bloom
#define BLOOM_TYPE 0 // 0=off 1=on
#define BLOOM_FACTOR 0.75 // from 0=none to 1=too_much

//////////////////////////
//////// Uniforms ////////
//////////////////////////

const float typeBasic = 0.0;
const float typeGlowing = 0.8;
const float typeTransparentLit = 0.5;
const float typeWater = 0.6;
const float typeOpaqueLit = 1.0;

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

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

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

uniform int frameCounter; // in [0;720719]
uniform int worldTime; // in tick [0;23999]
uniform int moonPhase; // 0=fullmoon, 1=waning gibbous, 2=last quarter, 3=waning crescent, 4=new, 5=waxing crescent, 6=first quarter, 7=waxing gibbous
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int isEyeInWater;
