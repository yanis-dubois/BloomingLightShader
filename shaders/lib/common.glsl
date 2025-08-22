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

////////////////////////////////////////////////////
//////////////////// parameters ////////////////////
////////////////////////////////////////////////////

// --- lighting --- //

// light
#define DIRECT_LIGHTING 1 //[0 1] 0=off 1=on
#define AMBIENT_LIGHTING 1 //[0 1] 0=off 1=on
#define SKY_LIGHT_COLOR 1 //[0 1] 0=constant 1=tweaked
#define BLOCK_LIGHT_COLOR 1 //[0 1] 0=constant 1=tweaked
#define FACE_TWEAK 1 //[0 1] 0=off 1=on
#define SPLIT_TONING 1 //[0 1] 0=off 1=on (give a blueish tint to shadows)

// shadows
#define SHADOW_TYPE 1 //[0 1 2] 0=off 1=stochastic 2=classic+rotation 3=classic
#define SHADOW_DITHERING_TYPE 1 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise
#define SHADOW_RANGE 3 //[1 2 3 4 5 6 7 8 9] radius of the sample area in shadowmap pixels
#define SHADOW_SAMPLES 8 //[1 2 4 6 8 12 16] number of samples (in total for stochastic / in radius for classic)
#define SHADOW_KERNEL 0 //[0 1] 0=box 1=gaussian

// light shaft
#define VOLUMETRIC_LIGHT_TYPE 1 //[0 1] 0=off 1=on
#define VOLUMETRIC_LIGHT_DITHERING_TYPE 1 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise
#define VOLUMETRIC_LIGHT_RESOLUTION 1.5 //[0.25 0.5 1.0 1.5 2.0 4.0] in [0;inf] 0.5=one_sample_each_two_block 1=one_sample_per_block 2=two_sample_per_block
#define VOLUMETRIC_LIGHT_MIN_SAMPLE 4 //[1 2 4 8 16]
#define VOLUMETRIC_LIGHT_MAX_SAMPLE 8 //[2 4 8 16 32 64]
#define VOLUMETRIC_LIGHT_INTENSITY 1.0 //[0.25 0.5 1.0 1.5 2.0]
// underwater light shaft
#define UNDERWATER_LIGHTSHAFT_TYPE 2 //[0 1 2] 0=off 1=static 2=animated

// pixelated shadding
#define TEXTURE_RESOLUTION 16 // [1 2 4 8 16 32 64 128 256 512 1024 2048]
#define PIXELATION_TYPE 2 //[0 1 2] 0=off 1=voxelisation 2=texture_snap
#define PIXELATED_SHADOW 2 //[0 1 2] 0=off 1=hard 2=smooth
#define PIXELATED_SPECULAR 1 //[0 1] 0=off 1=on
#define PIXELATED_BLOCKLIGHT 1 //[0 1] 0=off 1=on
#define PIXELATED_AMBIENT_OCCLUSION 1 //[0 1] 0=off 1=on
#define PIXELATED_REFLECTION 0 //[0 1] 0=off 1=on

// --- material --- //

// PBR texture pack
// only support labPBR
#define PBR_TYPE 0 //[0 1] 0=off 1=on
// customisable params
#define PBR_NORMAL_MAP 1 //[0 1] 0=off 1=on
#define PBR_AMBIENT_OCCLUSION 1 //[0 1] 0=off 1=on
#define PBR_SPECULAR 1 //[0 1] 0=off 1=on
#define PBR_EMISSIVNESS 1 //[0 1] 0=off 1=on
#define PBR_SUBSURFACE 0 //[0 1] 0=off 1=on
#define PBR_POROSITY 0 //[0 1] 0=off 1=on
// parallax occlusion mapping (POM)
#define PBR_POM_TYPE 2 //[0 1 2] 0=off 1=basicPOM 2=customPOM[better with low def textures] (parallax occlusion mapping needs height field)
#define PBR_POM_DITHERING_TYPE 2 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise
#define PBR_POM_DEPTH 0.25 //[0.0625 0.125 0.1875 0.25 0.3125 0.375 0.4375 0.5 0.5625 0.625 0.6875 0.75 0.8125 0.875 0.9375 1.0] in [0;1] - 0=no_depth, 1/16=1_pixel_depth 1=1_block_depth
#define PBR_POM_DISTANCE 16.0 //[8.0 16.0 32.0 64.0] in [8;+inf] spherical distance in blocks
#define PBR_POM_LAYERS 128 //[32 64 128 256] (only available with PBR_POM=1)
#define PBR_POM_NORMAL 1 //[0 1] 0=off 1=on activate POM generated normals (only available with PBR_POM=2)

// custom materials
#define CUSTOM_MATERIAL 1 //[0 1] 0=off 1=on add custom material values (roughness, reflectance, emissivness, ...)
#define EMISSVNESS_TYPE 1
#define SPECULAR_TYPE 1

// custom normalmap
#define CUSTOM_NORMALMAP 0 //[0 1] 0=off 1=on (procedurally generate normalmap : PBR override it)
#define WATER_CUSTOM_NORMALMAP 1 //[0 1] 0=off 1=on (custom normalmap for water : override PBR)

// subsurface scattering
#define SUBSURFACE_TYPE 1 //[0 1] 0=off 1=on

// porority
#define POROSITY_TYPE 1 //[0 1] 0=off 1=on

// custom ambient occlusion
#define AMBIENT_OCCLUSION_TYPE 1 //[0 1] 0=off 1=on custom ambient occlusion for props
#define VANILLA_AMBIENT_OCCLUSION_TYPE 1 //[0 1] 0=off 1=on vanilla ambient occlusion

// reflection
#define REFLECTION_TYPE 3 //[0 1 2 3] 0=off 1=fresnel_effect 2=mirror_reflection 3=SSR
#define REFLECTION_NORMAL_DITHERING_TYPE 2 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise
#define REFLECTION_STEP_DITHERING_TYPE 3 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise
#define REFLECTION_RESOLUTION 1.0 //[0.1 0.25 0.5 0.75 1.0] from 0=low to 1=high
#define REFLECTION_MAX_STEPS 12 //[2 4 8 12 16 32 64] from 0=none to inf=too_much
#define REFLECTION_THICKNESS 5 //[3 5 7 11 17 31] from 0=too_precise to inf=awful
#define REFLECTION_LAST_BLUR_SAMPLES 1 // [0;inf]

// emissive ores
#define EMISSIVE_ORES 0 //[0 1] 0=off 1=on

// --- atmospheric --- //

// sky
#define SKY_TYPE 1 //[0 1] 0=vanilla 1=custom
#define SKY_DITHERING_TYPE 1 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise

// fog
#define FOG_TYPE 2 //[0 1 2] 0=off 1=vanilla 2=custom

// water caustics
#define WATER_CAUSTIC_TYPE 1 //[0 1 2] 0=off 1=vanilla+ 2=realistic

// animation
#define ANIMATED_POSITION 2 //[0 1 2] 0=off 1=only_vertex 2=vertex_and_normal

// --- post process --- //

// bloom
#define BLOOM_TYPE 2 //[0 1 2] 0=off 1=old_school 2=modern
#define BLOOM_DITHERING_TYPE 2 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise
#define BLOOM_FACTOR 1.0 //[0.25 0.5 1.0 1.5 2.0 2.5 3.0] from 0=none to inf=too_much
// old bloom params
#define BLOOM_OLD_RANGE 0.015 //[0.005 0.01 0.015 0.02 0.025 0.03] extent of the kernel
#define BLOOM_OLD_RESOLUTION 0.5 //[0.1 0.25 0.5 0.75 0.9 1.0] in [0;1], proportion of pixel to be sampled
#define BLOOM_OLD_KERNEL 1 // 0=box 1=gaussian
#define BLOOM_OLD_STD 0.5 // standard deviation (only for gaussian kernel)
// modern bloom params
#define BLOOM_MODERN_RANGE 0.5 //[-2.0 -1.5 -1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0 1.5 2.0] in [-2;2]
#define BLOOM_MODERN_SAMPLES 1 //[1 2 3 4] number of samples in the radius 
#define BLOOM_MODERN_TYPE 1 //[0 1] 0=low 1=high

// depth of field
#define DOF_TYPE 0 //[0 1 2] 0=off 1=dynamic_focus 2=static_focus
#define DOF_RANGE 0.005 //[0.0025 0.005 0.0075 0.01] extent of the kernel
#define DOF_RESOLUTION 0.5 //[0.25 0.5 0.75 1.0] in [0;1], proportion of pixel to be sampled
#define DOF_KERNEL 0 //[0 1] 0=box 1=gaussian
#define DOF_STD 0.5 // standard deviation (only for gaussian kernel)
#define DOF_FOCAL_PLANE_LENGTH 20 //[5 10 20 40] half length in blocks
#define DOF_BOKEH 1 //[0 1] // 0=off 1=on

// temporal anti aliasing
#define TAA_TYPE 2 //[0 1 2] 0=off 1=soft[denoise] 2=hard[denoise & anti aliasing]

// light refraction effect
#define REFRACTION_UNDERWATER 1 //[0 1] 0=off 1=on
#define REFRACTION_NETHER 1 //[0 1] 0=off 1=on

// players status
#define STATUS_DYING_TYPE 1 //[0 1] 0=off 1=on
#define STATUS_STARVING_TYPE 1 //[0 1] 0=off 1=on
#define STATUS_DROWNING_TYPE 1 //[0 1] 0=off 1=on

// quantization
#define QUANTIZATION_TYPE 0 //[0 1 2] 0=off 1=on 2=dithered
#define QUANTIZATION_AMOUNT 1.0 //[1.0 2.0 4.0 8.0 16.0 32.0 64.0 128.0 256.0 512.0 1024.0] number of color used

// chromatic aberation
#define CHROMATIC_ABERATION_TYPE 0 //[0 1] 0=off 1=on
#define CHROMATIC_ABERATION_AMPLITUDE 0.02 //[0.005 0.01 0.015 0.02] 0=off 0.02=too_much

// --- distant horizon --- //

#define DH_DITHERING_TYPE 2 // 0=off 1=interleavedGradient 2=bayer 3=blueNoise

///////////////////////////////////////////////////
//////////////////// constants ////////////////////
///////////////////////////////////////////////////

// sun & moon
const float sunPathRotation = 0.0;

// shadow
const bool shadowHardwareFiltering = true;
const int shadowMapResolution = 2048; //[512 1024 2048 4096]
const float shadowDistanceRenderMul = 1.0;
const float shadowDistance = 192.0; //[96.0 128.0 192.0 256.0 512.0 1024.0]
const float startShadowDecrease = 0.66 * shadowDistance;

// noise
const int noiseTextureResolution = 64;

// depth of field
const float centerDepthHalflife = 2.0;

// effects
const float blindnessRange = 8.0;
const float darknessRange = 32.0;

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
uniform float currentPlayerAir;
uniform float currentPlayerHunger;
uniform float currentPlayerHealth;

uniform int blockEntityId;
uniform int entityId;
uniform int currentRenderedItemId;
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
uniform float inRainyBiome;

uniform int frameMod8;
uniform int frameMod16;

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

#if defined OVERWORLD
    const float seaLevel = 62.0;
#elif defined NETHER
    const float seaLevel = 30.0;
#else
    const float seaLevel = 52.0;
#endif
