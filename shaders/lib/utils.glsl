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
// from [0;1] to [0;inf]
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
float pseudoRandom(float pos) {
    return fract(sin(pos * 31.9428) * 91832.19424);
}
float pseudoRandom(vec2 pos) {
    return fract(sin(dot(pos, vec2(12.9898, 78.233))) * 43758.5453);
}
float pseudoRandom(vec3 pos){
    return fract(sin(dot(pos, vec3(64.25375463, 23.27536534, 86.29678483))) * 59482.7542);
}
float pseudoRandom(vec4 pos) {
    return fract(sin(dot(pos, vec4(12.9898, 78.233, 45.164, 94.618))) * 46367.21473);
}
vec2 sampleDiskArea(vec2 seed) {
    // pseudo uniform 
    float zeta1 = pseudoRandom(seed);
    float zeta2 = pseudoRandom(seed + 0.5);

    // uniform to polar
    float theta = zeta1 * 2.0*PI;
    float radius = sqrt(zeta2);

    // polar to cartesian
    float x = radius * cos(theta);
    float y = radius * sin(theta);

    return vec2(x,y);
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
    range  = isFirstPass ? normalizedRange / ratio : normalizedRange;
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

// ---------------------- //
// -- vertex animation -- //
// ---------------------- //
bool isWater(int id) {
    return id == 20000;
}
bool isAnimated(int id) {
    return 10000 <= id && (id <= 10050 || id == 20000 || id == 30010 || id == 30020);
}
bool isLiquid(int id) {
    return id == 20000 || id == 10040;
}
bool isLeaves(int id) {
    return id == 10030;
}
bool isVines(int id) {
    return id == 10032;
}
bool isHangingMoss(int id) {
    return id == 10031;
}
// leaves & vines
bool isFoliage(int id) {
    return isLeaves(id) || isHangingMoss(id) || isVines(id);
}
// bamboo, pumpkin & melon
bool isSolidFoliage(int id) {
    return id == 10080;
}
// roots, grass, flowers, mushroom, ...
bool isUnderGrowth(int id) {
    return 10000 <= id && id < 20000 && !isFoliage(id);
}
bool isRooted(int id) {
    return isUnderGrowth(id) && id != 10021 && id != 10022;
}
// root type
bool isThin(int id) {
    return id == 10001 || id == 10012 || id == 10013;
}
bool isSmall(int id) {
    return id == 10002;
}
bool isTiny(int id) {
    return id == 10003;
}
bool isTeensy(int id) {
    return id == 10004 || id == 10040;
}
bool isCeilingRooted(int id) {
    return id == 10020;
}
bool isTallLower(int id) {
    return id == 10010 || id == 10051 || id == 10012;
}
bool isTallUpper(int id) {
    return id == 10011 || id == 10052 || id == 10013;
}
bool isPicherCropLower(int id) {
    return id == 10008;
}
bool isPicherCropUpper(int id) {
    return id == 10009;
}
// ---------------------- //
// ----- subsurface ----- //
// ---------------------- //
bool hasNoAmbiantOcclusion(int id) {
    return isFoliage(id) || isSolidFoliage(id) || isTeensy(id) || id == 10022;
}
bool hasSubsurface(int id) {
    return 10000 <= id && id < 20000;
}
bool isColumnSubsurface(int id) {
    return id == 10021 || id == 10055 || id == 10060;
}
bool isCobweb(int id) {
    return id == 10070;
}
// ---------------------- //
// --- animated light --- //
// ---------------------- //
bool animatedLight_isHigh(int id) {
    return true;
}
bool animatedLight_isMedium(int id) {
    return true;
}
bool animatedLight_isLow(int id) {
    return true;
}
////////////////
bool hasNormalJittering(int id) {
    return id == 20000 || id == 20013;
}

// offset midBlock coordinate to make the root of foliage the origin
vec3 midBlockToRoot(int id, vec3 midBlock) {
    if (isSmall(id)) midBlock.y *= 2.0;
    else if (isTiny(id)) midBlock.y *= 4.0;
    else if (isCeilingRooted(id)) midBlock.y = 1.0 - midBlock.y;
    else if (isTallLower(id)) midBlock.y *= 0.5;
    else if (isTallUpper(id)) midBlock.y = midBlock.y * 0.5 + 0.5;
    else if (isPicherCropLower(id)) midBlock.y = max(midBlock.y * 0.6875 - 0.3125, 0.0);
    else if (isPicherCropUpper(id)) midBlock.y = midBlock.y * 0.6875 + 0.6875 - 0.3125;

    return midBlock;
}
