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
const int noiseTextureResolution = 256;
const int shadowMapResolution = 2048;

//////////////////////////
/////// Parameters ///////
//////////////////////////

// sun and moon
const float sunPathRotation = 2;

// shadows
#define SHADOW_QUALITY 5. // number of samples 
#define SHADOW_SOFTNESS 1. // width of the sample area

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;
const float startShadowDecrease = 100; // 100?
const float endShadowDecrease = 150; // 150?

// Screen Space Ambiant Occlusion (SSAO)
#define SSAO_SAMPLES 0 // number of samples
#define SSAO_RADIUS 1
#define SSAO_BIAS 0
#define SSAO_MAGNITUDE 1.5
#define SSAO_CONTRAST 1.5

// Screen Space Reflection (SSR)
#define SSR_ONLY_FRESNEL 0 // 0=no; 1=yes
#define SSR_RESOLUTION 0.25 // from 0=low to 1=high
#define SSR_STEPS 10 // from 0=none to inf=too_much
#define SSR_THICKNESS 0.5 // from 0=too_precise to inf=awful

//////////////////////////
//////// Uniforms ////////
//////////////////////////

uniform sampler2D noisetex;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform ivec2 eyeBrightness;

uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform float alphaTestRef;
uniform float near;
uniform float far;
uniform float viewHeight;
uniform float viewWidth;
uniform float gamma;

uniform int frameCounter; // in [0;720719]
uniform int worldTime; // in tick [0;23999]
uniform int moonPhase; // 0=fullmoon, 1=waning gibbous, 2=last quarter, 3=waning crescent, 4=new, 5=waxing crescent, 6=first quarter, 7=waxing gibbous
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int isEyeInWater;
