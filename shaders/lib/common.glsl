///////////////////////////////////////////////////
///////////////////// buffers /////////////////////
///////////////////////////////////////////////////

// format
/*
const int colortex0Format = RGBA8; // color
const int colortex1Format = RGB16F; // deferred = normal 
const int colortex2Format = RGB8; // TAA: last frame color
const int colortex3Format = R32F; // TAA: last frame depth
const int colortex4Format = RGBA8; // opaque gbuffer = material | deferred = opaque reflection | transparent gbuffer = opaque color | composite = bloom
const int colortex5Format = RGBA8; // deferred,composite1 = light data | composite>1 = depth of field mask
const int shadowcolor0Format = RGBA8; // shadow color
const int shadowcolor1Format = RGBA8; // light shaft color
*/

// flush buffer from a rendering to another
const bool colortex0Clear = true;
const bool colortex1Clear = true;
const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool colortex4Clear = true;
const bool colortex5Clear = true;

///////////////////////////////////////////////////
//////////////////// constants ////////////////////
///////////////////////////////////////////////////

// sun & moon
const float sunPathRotation = 0.0;

// shadow
const bool shadowHardwareFiltering = true;
const int shadowMapResolution = 1536; // 1024 1536 2048
const float startShadowDecrease = 100;
const float endShadowDecrease = 150;

// depth of field
const float centerDepthHalflife = 2.0;

// effects
const float blindnessRange = 8.0;
const float darknessRange = 32.0;

////////////////////////////////////////////////////
//////////////////// parameters ////////////////////
////////////////////////////////////////////////////

// PBR texture
// only support labPBR
#define PBR_TYPE 1 // 0=off 1=on
// porosity (only few texture pack specify porosity)
#define PBR_POROSITY 0 // 0=off 1=on
// parallax occlusion mapping (POM)
#define PBR_POM 2 // 0=off 1=basicPOM 2=customPOM[better with low def textures] (parallax occlusion mapping needs height field)
#define PBR_POM_DEPTH 8.0/16.0 // in [0;1] - 0=no_depth, 1/16=1_pixel_depth 1=1_block_depth
#define PBR_POM_DISTANCE 24.0 // in [8;+inf] spherical distance in blocks
#define PBR_POM_LAYERS 128 // 32 64 128 256 (only available with PBR_POM=1)
#define PBR_POM_NORMAL 1 // 0=off 1=on activate POM generated normals (only available with PBR_POM=2)

// sky
#define SKY_TYPE 1 // 0=vanilla 1=custom

// light
#define SKY_LIGHT_COLOR 1 // 0=constant 1=tweaked
#define BLOCK_LIGHT_COLOR 1 // 0=constant 1=tweaked
#define SPLIT_TONING 1 // 0=off 1=on (give a blueish tint to shadows)

// fog
#define FOG_TYPE 2 // 0=off 1=vanilla 2=custom

// pixelated shadding
#define TEXTURE_RESOLUTION 16 // 0=off 1=on
#define PIXELATED_SHADOW 2 // 0=off 1=hard 2=smooth
#define PIXELATED_SPECULAR 1 // 0=off 1=on
#define PIXELATED_REFLECTION 0 // 0=off 1=on

// custom normalmap for water
#define WATER_CUSTOM_NORMALMAP 1 // 0=off 1=on

// shadows
#define SHADOW_TYPE 1 // 0=off 1=stochastic 2=classic+rotation 3=classic 
#define SHADOW_RANGE 0.66 // width of the sample area (in clip) 0.66
#define SHADOW_SAMPLES 4 // number of samples (for stochastic) 4
#define SHADOW_KERNEL 0 // 0=box 1=gaussian

// reflection
#define REFLECTION_TYPE 3 // 0=off 1=fresnel_effect 2=mirror_reflection 3=SSR
#define REFLECTION_RESOLUTION 1 // from 0=low to 1=high
#define REFLECTION_MAX_STEPS 16 // from 0=none to inf=too_much
#define REFLECTION_THICKNESS 5 // from 0=too_precise to inf=awful
#define REFLECTION_BLUR_RANGE 0.001 // extent of the kernel
#define REFLECTION_BLUR_RESOLUTION 0.5 // in [0;1], proportion of pixel to be sampled
#define REFLECTION_BLUR_KERNEL 0 // 0=box 1=gaussian
#define REFLECTION_BLUR_STD 0.5 // standard deviation (only for gaussian kernel)

// animation
#define ANIMATED_POSITION 2 // 0=off 1=only_vertex 2=vertex_and_normal

// subsurface scattering
#define SUBSURFACE_TYPE 1 // 0=off 1=on

// porority
#define POROSITY_TYPE 1 // 0=off 1=on

// light shaft
#define VOLUMETRIC_LIGHT_TYPE 1 // 0=off 1=on
#define VOLUMETRIC_LIGHT_RESOLUTION 1.5 // in [0;inf] 0.5=one_sample_each_two_block 1=one_sample_per_block 2=two_sample_per_block
#define VOLUMETRIC_LIGHT_MIN_SAMPLE 4
#define VOLUMETRIC_LIGHT_MAX_SAMPLE 8
#define VOLUMETRIC_LIGHT_INTENSITY 1
#define UNDERWATER_LIGHTSHAFT_TYPE 2 // 0=off 1=on 2=animated

// bloom
#define BLOOM_TYPE 2 // 0=off 1=old_school 2=modern
// old bloom params
#define BLOOM_OLD_RANGE 0.015 // extent of the kernel
#define BLOOM_OLD_RESOLUTION 0.5 // in [0;1], proportion of pixel to be sampled
#define BLOOM_OLD_KERNEL 1 // 0=box 1=gaussian
#define BLOOM_OLD_STD 0.5 // standard deviation (only for gaussian kernel)
// modern bloom params
#define BLOOM_MODERN_RANGE 1 // in [-2;2]
#define BLOOM_MODERN_RESOLTUION 2 // number of samples in the radius 
#define BLOOM_FACTOR 1.0 // from 0=none to inf=too_much

// depth of field
#define DOF_TYPE 0 // 0=off 1=dynamic_focus 2=static_focus
#define DOF_RANGE 0.005 // extent of the kernel
#define DOF_RESOLUTION 1 // in [0;1], proportion of pixel to be sampled
#define DOF_KERNEL 0 // 0=box 1=gaussian
#define DOF_STD 0.5 // standard deviation (only for gaussian kernel)
#define DOF_FOCAL_PLANE_LENGTH 20 // half length in blocks

// temporal anti aliasing
#define TAA_TYPE 2 // 0=off 1=soft[denoise] 2=hard[denoise & anti aliasing]

// water caustics
#define WATER_CAUSTIC_TYPE 2 // 0=off 1=vanilla+ 2=realistic

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
uniform float thunderStrength;
uniform float wetness;
uniform float alphaTestRef;
uniform float near;
uniform float far;
uniform float viewHeight;
uniform float viewWidth;
uniform float frameTimeCounter;
uniform float ambientLight;
uniform float centerDepthSmooth;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;

uniform int blockEntityId;
uniform int frameCounter; // in [0;720719]
uniform int worldTime; // in tick [0;23999]
uniform int moonPhase; // 0=fullmoon, 1=waning gibbous, 2=last quarter, 3=waning crescent, 4=new, 5=waxing crescent, 6=first quarter, 7=waxing gibbous
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int isEyeInWater;
uniform int biome_precipitation;

#ifdef DISTANT_HORIZONS
    uniform float dhNearPlane;
    uniform float dhFarPlane;
    uniform int dhRenderDistance;
#endif

////////////////////////////////////////////////////
///////////////// custom uniforms //////////////////
////////////////////////////////////////////////////

uniform float gamma;
uniform float framemod8;
uniform float inRainyBiome;

////////////////////////////////////////////////////
///////////////// custom constants /////////////////
////////////////////////////////////////////////////

const vec3 eastDirection = vec3(1.0, 0.0, 0.0);
const vec3 westDirection = vec3(-1.0, 0.0, 0.0);
const vec3 upDirection = vec3(0.0, 1.0, 0.0);
const vec3 downDirection = vec3(0.0, -1.0, 0.0);
const vec3 northDirection = vec3(0.0, 0.0, -1.0);
const vec3 southDirection = vec3(0.0, 0.0, 1.0);

const float PI = 3.14159265359;
const float e = 2.71828182846;
