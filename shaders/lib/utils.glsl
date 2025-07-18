// -- gamma correction -- //
float SRGBtoLinear(float x) {
    return pow(x, gamma);
}
vec2 SRGBtoLinear(vec2 x) {
    return pow(x, vec2(gamma));
}
vec3 SRGBtoLinear(vec3 x) {
    return pow(x, vec3(gamma));
}
vec4 SRGBtoLinear(vec4 x) {
    return pow(x, vec4(gamma));
}
float linearToSRGB(float x) {
    return clamp(pow(x, 1.0/gamma), 0.0, 1.0);
}
vec2 linearToSRGB(vec2 x) {
    return clamp(pow(x, vec2(1.0/gamma)), 0.0, 1.0);
}
vec3 linearToSRGB(vec3 x) {
    return clamp(pow(x, vec3(1.0/gamma)), 0.0, 1.0);
}
vec4 linearToSRGB(vec4 x) {
    return clamp(pow(x, vec4(1.0/gamma)), 0.0, 1.0);
}

// -- color stuff -- //
vec3 getLuminance(vec3 color) {
    return vec3(dot(color, vec3(0.2126, 0.7152, 0.0722)));
}
float getLightness(vec3 color) {
    return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}
vec3 saturate(vec3 color, float factor) {
    return mix(getLuminance(color), color, factor);
}
// from [0;inf] to [0;1]
vec3 toneMap(vec3 color) {
    return color / (1.0 + getLightness(color));
}
// from [0;1] to [0;1000]
vec3 inverseToneMap(vec3 color) {
    return color / max(1.0 - getLightness(color), 0.001);
}
vec3 rgbToHsv(vec3 c) {
    vec4 p = (c.g < c.b) ? vec4(c.bg, -1.0, 2.0 / 3.0) : vec4(c.gb, 0.0, -1.0 / 3.0);
    vec4 q = (c.r < p.x) ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10; // Small epsilon to avoid division by zero
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsvToRgb(vec3 c) {
    vec3 p = abs(fract(c.x + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// -- random generator -- //
// -- pseudo white noise
float interleavedGradient(float seed) {
    return fract(sin(seed * 31.9428) * 91832.19424);
}
float interleavedGradient(vec2 seed) {
    return fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
}
float interleavedGradient(vec3 seed){
    return fract(sin(dot(seed, vec3(64.25375463, 23.27536534, 86.29678483))) * 59482.7542);
}
float interleavedGradient(vec4 seed) {
    return fract(sin(dot(seed, vec4(12.9898, 78.233, 45.164, 94.618))) * 46367.21473);
}
// -- pseudo blue noise
// Bayer matrix (4x4)
const mat4 bayerMatrix = mat4(
    0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
    3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
);
const ivec2 offsets[2] = ivec2[] (
    ivec2(1),
    ivec2(1,-1)
);
float bayer(vec2 uv) {
    ivec2 pixelPos = ivec2(uv * vec2(viewWidth, viewHeight));

    #if TAA_TYPE > 0
        pixelPos = (pixelPos + offsets[frameMod8>3?0:1] * ivec2(frameMod8%4)) % 4;
    #else
        pixelPos = pixelPos % 4;
    #endif

    return bayerMatrix[pixelPos.x][pixelPos.y] / 16.0;
}
// -- blue noise
// blue noise texture
uniform sampler2D noisetex;
// blue noise 
float blueNoise(vec2 uv) {
    vec2 pixelPos = uv * vec2(viewWidth, viewHeight);

    #if TAA_TYPE > 0
        vec2 pixelPos64 = mod(uv * vec2(viewWidth, viewHeight) + 8*frameMod8, noiseTextureResolution) / noiseTextureResolution;
    #else
        vec2 pixelPos64 = mod(uv * vec2(viewWidth, viewHeight), noiseTextureResolution) / noiseTextureResolution;
    #endif

    return texture2D(noisetex, pixelPos64).r;
}
// -- dithering
float dithering(vec2 uv, int ditheringType) {
    if (ditheringType == 1)
        return interleavedGradient(uv + frameTimeCounter/3600.0);
    if (ditheringType == 2)
        return bayer(uv);
    if (ditheringType == 3)
        return blueNoise(uv);
    return 0.5;
}

// -- sampling and generating -- //
vec2 sampleDiskArea(float zeta1, float zeta2) {

    // uniform to polar
    float theta = zeta1 * 2.0*PI;
    float radius = sqrt(zeta2);

    // polar to cartesian
    float x = radius * cos(theta);
    float y = radius * sin(theta);

    return vec2(x,y);
}
mat2 rotationMatrix(float theta) {
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);

    return mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
}
mat2 randomRotationMatrix(float noise) {
    return rotationMatrix(noise * 2.0*PI);
}

// -- cartesian & polar coordinates conversions -- //
vec3 cartesianToPolar(vec3 cartesianCoordinate) {
    float x = cartesianCoordinate.x;
    float y = cartesianCoordinate.y;
    float z = cartesianCoordinate.z;

    float x2 = x * x;
    float y2 = y * y;
    float z2 = z * z;

    float radius = sqrt(x2 + y2 + z2);
    float theta = acos(z / radius);
    float phi = sign(y) * acos(x / sqrt(x2 + y2));

    return vec3(theta, phi, radius);
}
vec3 polarToCartesian(vec3 polarCoordinate) {
    float theta = polarCoordinate.x;
    float phi = polarCoordinate.y;
    float radius = polarCoordinate.z;

    float sinTheta = sin(theta);

    float x = radius * sinTheta * cos(phi);
    float y = radius * sinTheta * sin(phi);
    float z = radius * cos(theta);

    return vec3(x, y, z);
}

// -- interval stuff -- //
bool isInRange(int x, int min_, int max_) {
    return min_ <= x && x <= max_;
}
bool isInRange(float x, float min_, float max_) {
    return min_ <= x && x <= max_;
}
bool isInRange(vec2 xy, float min_, float max_) {
    return isInRange(xy.x, min_, max_) && isInRange(xy.y, min_, max_);
}
bool isInRange(vec2 xy, vec2 min_, vec2 max_) {
    return isInRange(xy.x, min_.x, max_.x) && isInRange(xy.y, min_.y, max_.y);
}
bool isInRange(vec3 xyz, float min_, float max_) {
    return isInRange(xyz.xy, min_, max_) && isInRange(xyz.z, min_, max_);
}
float map(float value, float fromMin, float fromMax, float toMin, float toMax) {
    float mapped = (value-fromMin) / (fromMax-fromMin); // from [fromMin;fromMax] to [0;1]
    return clamp(mapped*(toMax-toMin) + toMin, toMin, toMax); // from [0;1] to [toMin;toMax]
}
vec3 map(vec3 value, float fromMin, float fromMax, float toMin, float toMax) {
    vec3 mapped = (value-fromMin) / (fromMax-fromMin); // from [fromMin;fromMax] to [0;1]
    return clamp(mapped*(toMax-toMin) + toMin, toMin, toMax); // from [0;1] to [toMin;toMax]
}
bool isEqual(float x, float y, float epsilon) {
    return abs(x - y) <= epsilon;
}
bool isEqual(vec3 x, vec3 y, float epsilon) {
    return isEqual(x.x, y.x, epsilon) && isEqual(x.y, y.y, epsilon) && isEqual(x.z, y.z, epsilon);
}

// -- distance -- //
float distance1(vec2 p1, vec2 p2) {
    return abs(p2.x - p1.x) + abs(p2.y - p1.y);
}
float distanceInf(vec2 p1, vec2 p2) {
    return max(abs(p2.x - p1.x), abs(p2.y - p1.y));
}
float distanceInf(vec3 p1, vec3 p2) {
    return max(distanceInf(p1.xy, p2.xy), abs(p2.z - p1.z));
}

// -- gaussian -- //
float gaussian(float x, float y, float mu, float sigma) {
    return exp(- (((x-mu)*(x-mu) + (y-mu)*(y-mu)) / (2.0*sigma*sigma)));
}
float gaussian(float x, float y, float sigma) {
    return exp(- ((x*x + y*y) / (2.0*sigma*sigma)));
}
float gaussian(float x, float sigma) {
    return exp(- ((x*x) / (2.0*sigma*sigma)));
}

// -- very specific stuff -- //
// assure consistency for all screen size
void prepareBlurLoop(float normalizedRange, float resolution, bool isFirstPass,
                    out float range, out float stepLength) {
    float ratio = viewWidth / viewHeight;
    range = isFirstPass ? normalizedRange / ratio : normalizedRange;
    float pixels  = isFirstPass ? viewWidth * range : viewHeight * range;
    pixels = floor(pixels);
    if (pixels <= 0.0) {
        range = 0.0;
        stepLength = 1.0;
    }
    float samples = pixels * resolution;
    stepLength = range / samples;
}
// day-night transition
float getDayNightBlend() {
    return map(shadowAngle, 0.0, 0.02, 0.0, 1.0) * map(shadowAngle, 0.5, 0.48, 0.0, 1.0);
}
// [0;1] new=0, full=1
float getMoonPhase() {
    float moonPhaseBlend = moonPhase < 4 ? float(moonPhase) / 4.0 : (4.0 - (float(moonPhase)-4.0)) / 4.0; 
    return cos(moonPhaseBlend * PI) / 2.0 + 0.5; 
}
// voxelize position
vec3 voxelize(vec3 worldSpacePosition) {
    return floor((worldSpacePosition + 0.001) * TEXTURE_RESOLUTION) / TEXTURE_RESOLUTION + 1.0/(2.0*TEXTURE_RESOLUTION);
}
vec3 voxelize(vec3 worldSpacePosition, vec3 normal) {
    float halfStep = 1.0 / (2.0*TEXTURE_RESOLUTION);
    worldSpacePosition = floor((worldSpacePosition + normal * 0.001) * TEXTURE_RESOLUTION) / TEXTURE_RESOLUTION;
    worldSpacePosition += halfStep;
    worldSpacePosition -= normal * halfStep;
    return worldSpacePosition;
}

// -- data encoding & decoding -- //
vec3 encodeNormal(vec3 normal) {
    return (normal + 1.0) / 2.0; // from [-1;1] to [0;1]
}
vec3 decodeNormal(vec3 normal) {
    return normal * 2.0 - 1.0; // from [0;1] to [-1;1]
}
void getColorData(vec4 colorData, out vec3 albedo, out float transparency) {
    albedo = colorData.rgb;
    transparency = colorData.a;
    albedo = SRGBtoLinear(albedo);
}
void getNormalData(vec4 normalData, out vec3 normal) {
    normal = normalData.xyz;
    normal = decodeNormal(normal);
}
void getLightData(vec4 lightData, out float blockLightIntensity, out float ambiantSkyLightIntensity, out float emissivness, out float ambiant_occlusion) {
    vec2 receivedLight = lightData.xy;
    receivedLight = SRGBtoLinear(receivedLight);
    blockLightIntensity = receivedLight.x;
    ambiantSkyLightIntensity = receivedLight.y;
    emissivness = lightData.z;
    ambiant_occlusion = 1.0 - map(lightData.w, 0.5, 1.0, 0.0, 1.0);
}
void getMaterialData(vec4 materialData, out float type, out float smoothness, out float reflectance, out float subsurface) {
    type = materialData.x;
    smoothness = materialData.y;
    reflectance = materialData.z;
    subsurface = materialData.w;
}
void getDepthData(vec4 depthData, out float depth) {
    depth = depthData.x;
}


// --- specific materials --- //
bool isWater(int id) {
    return id == 1;
}
bool isUncoloredGlass(int id) {
    return id == 3500;
}
bool isBeacon(int id) {
    return id == 20016;
}
bool isEndPortal(int id) {
    return id == 29001;
}
bool isVine(int id) {
    return id == 11201;
}
bool hasGrass(int id) {
    return id == 1701 || id == 1800 || id == 2200;
}

// --- animation --- //
bool hasWaterAnimation(int id) {
    return isWater(id) || id == 11300;
}
bool hasLeavesAnimation(int id) {
    return id == 3700 || id == 11200 || isVine(id);
}
bool hasGrassAnimation(int id) {
    return 10000 <= id && id < 11200;
}
bool isAnimated(int id) {
    return hasWaterAnimation(id) || hasLeavesAnimation(id) || hasGrassAnimation(id);
}
bool isRooted(int id) {
    return 10000 <= id && id < 11000;
}

// --- smoothness --- //
bool isVerySmooth(int id) {
    return id == 21
        || (3500 <= id && id < 3600)
        || (29000 <= id && id < 29100);
}
bool isSmooth(int id) {
    return id == 605
        || (1100 <= id && id < 1200)
        || (2702 <= id && id < 3000)
        || (3300 <= id && id < 3400)
        || (3702 <= id && id < 3800)
        || id == 3803
        || id == 3901
        || (11800 <= id && id <= 11803)
        || id == 20032 
        || id == 20033
        || id == 20042
        || id == 20046
        || id == 20100
        || id == 20200
        || id == 20205
        || (20400 <= id && id < 20500);
}
bool isSlightlySmooth(int id) {
    return id == 20
        || (800 <= id && id < 1100)
        || id == 1704
        || (2400 <= id && id < 2500)
        || (3000 <= id && id < 3100)
        || (4000 <= id && id < 4200)
        || id == 20007;
}
bool isSlightlyRough(int id) {
    return (300 <= id && id < 600)
        || (700 <= id && id < 800)
        || (1200 <= id && id < 1300)
        || (1900 <= id && id < 2100)
        || (2600 <= id && id <= 2701)
        || (3100 <= id && id < 3200)
        || id == 3700
        || id == 3701
        || id == 3800
        || id == 3802
        || id == 3804
        || id == 3805
        || id == 3900
        || (4200 <= id && id < 4300)
        || id == 10202
        || (10300 <= id && id < 10400)
        || (20000 <= id && id <= 20006)
        || (20008 <= id && id <= 20021)
        || (20025 <= id && id <= 20030)
        || (20035 <= id && id <= 20046);
}
bool isRough(int id) {
    return (200 <= id && id < 300)
        || (600 <= id && id < 700)
        || (1400 <= id && id < 1700)
        || (2100 <= id && id < 2300)
        || (2300 <= id && id < 2400)
        || (3200 <= id && id < 3300)
        || id == 3401;
}

// --- reflectance --- //
bool hasMetallicReflectance(int id) {
    return (2600 <= id && id < 3400)
        || (11800 <= id && id <= 11803)
        || id == 20007
        || id == 20042
        || id == 20046
        || (20400 <= id && id < 20500);
}
bool hasHighReflectance(int id) {
    return id == 20
        || id == 21
        || id == 605
        || (1100 <= id && id < 1200)
        || (3500 <= id && id < 3600)
        || (4100 <= id && id < 4200)
        || id == 20016
        || id == 20029
        || id == 20032
        || id == 20033
        || id == 20100
        || id == 20200
        || id == 20205
        || (29000 <= id && id < 29100);
}
bool hasMediumReflectance(int id) {
    return (600 <= id && id < 1300)
        || (2400 <= id && id < 2500)
        || id == 10202
        || id == 20002
        || id == 20005
        || id == 20008
        || id == 20009
        || id == 20014
        || id == 20015
        || id == 20018
        || id == 20019
        || id == 20036
        || id == 20037
        || id == 20039
        || id == 20040
        || id == 20041
        || id == 20043
        || id == 20044;
}

// --- emissivness --- //
bool isFullyEmissive(int id) {
    return id == 1100 
        #if EMISSIVE_ORES > 0
            || id == 2603
        #endif
        || id == 2701
        || id == 29000
        || id == 30000
        || id == 40000
        || id == 40001;
}
bool isSemiEmissive(int id) {
    return id == 2
        || id == 10
        || id == 11
        || id == 109
        || id == 110
        || (1100 < id && id < 1200)
        || id == 2101
        || id == 2906
        || id == 3006
        || id == 3106
        || id == 3206 
        || id == 3704
        || id == 3900
        || id == 3901
        || id == 4000
        || id == 4004
        || id == 4201
        || id == 10002
        || id == 10003
        || id == 10301
        || id == 10401
        || id == 10601
        || id == 11001
        || (11800 <= id && id < 11900)
        || id == 20009
        || id == 20016
        || id == 20029
        || id == 20033
        || (20200 <= id && id < 20300)
        || id == 20403
        || id == 20404
        || id == 20502
        || id == 30100
        || id == 40100;
}
bool isLitRedstone(int id) {
    return id == 1205
        || id == 1214
        || (20300 <= id && id < 20400);
}
bool isOre(int id) {
    return (1200 <= id && id < 1300)
        || (2300 <= id && id < 2400);
}
bool isStoneOre(int id) {
    return (1200 <= id && id <= 1217);
}
bool isNetherrackOre(int id) {
    return (2300 <= id && id < 2400);
}
bool isBlackstoneOre(int id) {
    return id == 1218;
}

// --- subsurface --- //
bool hasSubsurface(int id) {
    return (20 <= id && id < 30)
        || (3600 <= id && id < 4300)
        || (10000 <= id && id < 11900);
}
// like grass, pointed dripstone or cobweb
bool isProps(int id) {
    return (10000 <= id && id < 20000) ;
}

// --- ambient occlusion --- //
bool hasAmbientOcclusion(int id) {
    return (10000 <= id && id < 20000) 
        && id != 10500
        && !(10800 <= id && id < 10900)
        && id != 10901
        && id != 11201 
        && !(11300 <= id && id < 11400)
        && !(11700 <= id && id < 11800);
}
// models that are more complex than two crossed planes
// force us to calculate ambient occlusion via midBlock other than UV
bool hasComplexeGeometry(int id) {
    return id == 10100
        || id == 10101
        || id == 10200
        || id == 10201
        || id == 10402 
        || id == 10901;
}
bool hasVerticalAmbientOcclusion(int id) {
    return (10100 <= id && id < 10200)
        || (10400 <= id && id < 10500);
}
bool hasHorizontalAmbientOcclusion(int id) {
    return (11000 <= id && id < 11100)
        || id == 11200
        || (11500 <= id && id < 11600);
}

// --- porosity --- //
bool hasHighPorosity(int id) {
    return (1300 <= id && id < 1400)
        || (1700 <= id && id < 1900)
        || id == 3400
        || (3600 <= id && id < 3700)
        || id == 3801
        || id == 3802;
}
bool hasLowPorosity(int id) {
    return (100 <= id && id < 600)
        || (1400 <= id && id < 1700)
        || id == 1900
        || id == 2100
        || (2200 <= id && id < 2400)
        || id == 3401
        || id == 3702
        || id == 3703
        || (20500 <= id && id < 20600);
}

// root type
bool isSmall(int id) {
    return (10600 <= id && id < 10700);
}
bool isTiny(int id) {
    return (10700 <= id && id < 10800);
}
bool isCeilingRooted(int id) {
    return (10900 <= id && id < 11000);
}
bool isTallUpper(int id) {
    return id == 10000 || id == 10002 || id == 10100 || id == 11401;
}
bool isTallLower(int id) {
    return id == 10001 || id == 10003 || id == 10101 || id == 11402;
}
bool isPicherCropUpper(int id) {
    return id == 10200;
}
bool isPicherCropLower(int id) {
    return id == 10201;
}

// offset midBlock coordinate to make the foliage's root the origin (used for vertex animation)
vec3 midBlockToRoot_animation(int id, vec3 midBlock) {
    if (isCeilingRooted(id)) midBlock.y = 1.0 - midBlock.y;
    else if (isTallLower(id)) midBlock.y *= 0.5;
    else if (isTallUpper(id)) midBlock.y = midBlock.y * 0.5 + 0.5;
    else if (isPicherCropLower(id)) midBlock.y = 0.5 * midBlock.y - 0.1875;
    else if (isPicherCropUpper(id)) midBlock.y = 0.5 * midBlock.y + 0.5 - 0.1875;

    return midBlock;
}
// offset midBlock coordinate to make the foliage's root the origin (used for custom ambient occlusion)
vec3 midBlockToRoot_ao(int id, vec3 midBlock) {
    if (isSmall(id)) midBlock.y *= 2.0;
    else if (isTiny(id)) midBlock.y *= 4.0;
    else if (isCeilingRooted(id)) midBlock.y = 1.0 - midBlock.y;
    else if (isTallLower(id)) midBlock.y *= 0.5;
    else if (isTallUpper(id)) midBlock.y = midBlock.y * 0.5 + 0.5;
    else if (isPicherCropLower(id)) midBlock.y = 0.5 * midBlock.y - 0.1875;
    else if (isPicherCropUpper(id)) midBlock.y = 0.5 * midBlock.y + 0.5 - 0.1875;

    return midBlock;
}
// offset local UV coordinate to make the root of foliage the origin (used for ambient occlusion)
vec2 offsetUV(int id, vec2 uv) {
    uv.x = uv.x * 2.0 - 1.0;

    if (isCeilingRooted(id)) return uv;

    uv.y = 1.0 - uv.y;
    if (isSmall(id)) uv.y * 2.0;
    else if (isTiny(id)) uv.y *= 4.0;
    else if (isTallLower(id)) uv.y *= 0.5;
    else if (isTallUpper(id)) uv.y = uv.y * 0.5 + 0.5;

    return uv;
}
