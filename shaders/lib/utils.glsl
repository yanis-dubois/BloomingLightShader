// -- -- //
vec4 addMatrixRows(mat4 matrix, int row1, int row2) {
    return vec4(
        matrix[0][row1] + matrix[0][row2],
        matrix[1][row1] + matrix[1][row2],
        matrix[2][row1] + matrix[2][row2],
        matrix[3][row1] + matrix[3][row2]
    );
}
vec4 subtractMatrixRows(mat4 matrix, int row1, int row2) {
    return vec4(
        matrix[0][row1] - matrix[0][row2],
        matrix[1][row1] - matrix[1][row2],
        matrix[2][row1] - matrix[2][row2],
        matrix[3][row1] - matrix[3][row2]
    );
}

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

// -- random generator -- //
float pseudoRandom(vec2 pos) {
    return fract(sin(dot(pos, vec2(12.9898, 78.233))) * 43758.5453);
}
float pseudoRandom(vec3 pos){
    return fract(sin(dot(pos, vec3(64.25375463, 23.27536534, 86.29678483))) * 59482.7542);
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
// find intersection between ray and frustum
vec3 rayFrustumIntersection(vec3 origin, vec3 direction, vec3 planes_normal[6], vec3 planes_point[6]) {

    // get intersections
    bool hasIntersection[6];
    vec3 intersections[6];
    for (int i=0; i<6; ++i) {
        hasIntersection[i] = true;

        vec3 normal = planes_normal[i];
        vec3 point = planes_point[i];

        float denom = dot(normal, direction);
        // segment parallel to the plane
        if (denom < 1e-6) {
            hasIntersection[i] = false;
            continue;
        }

        // compute intersection
        float t = - (dot(normal, (origin - point))) / denom;
        if (t > 0.0) {
            intersections[i] = origin + (t - 1e-2) * direction;
        } else {
            hasIntersection[i] = false;
        }
    }

    // keep only intersections that are inside frustum
    for (int i=0; i<6; ++i) {
        if (!hasIntersection[i]) continue;

        bool isInside = true;
        for (int j=0; j<6; ++j) {
            if (dot(-planes_normal[j], intersections[i] - planes_point[j]) < 0.0) {
                isInside = false;
                break;
            }
        }

        if (isInside) {
            return intersections[i];
        }
    }

    return vec3(0.0);
}
// assure consistency for all screen size
void prepareBlurLoop(float normalizedRange, float resolution, bool isFirstPass,
                    out float range, out float stepLength) {
    float ratio = viewWidth / viewHeight;
    range  = isFirstPass ? normalizedRange / ratio : normalizedRange;
    float pixels  = isFirstPass ? viewWidth * range : viewHeight * range;
    float samples = pixels * resolution;
    stepLength = range / samples;
}
// day-night transition
float getDayNightBlend() {
    return map(shadowAngle, 0.0, 0.02, 0.0, 1.0) * map(shadowAngle, 0.5, 0.48, 0.0, 1.0);
}
// 
float perspectiveMix(float a, float b, float factor) {
    return 1.0 / ( (1.0/a) + (factor * ((1.0/b) - (1.0/a))) );
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

// -- type checking -- //
bool areNearlyEqual(float x, float y) {
    return abs(x-y) < 0.15;
}
bool isBasic(float type) {
    return areNearlyEqual(type, typeBasic);
}
bool isParticle(float type) {
    return areNearlyEqual(type, typeParticle);
}
bool isWater(float type) {
    return areNearlyEqual(type, typeWater);
}
bool isLit(float type) {
    return areNearlyEqual(type, typeLit);
}

// ---------------------- //
// -- vertex animation -- //
// ---------------------- //
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
    return id == 10031;
}
// leaves & vines
bool isFoliage(int id) {
    return isLeaves(id) || isVines(id);
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

// offset midBlock coordinate to make the root of foliage the origin
vec3 midBlockToRoot(int id, vec3 midBlock) {
    midBlock /= 64.0;

    midBlock.y = -1.0 * midBlock.y + 0.5;
    if (isSmall(id)) midBlock.y *= 2.0;
    else if (isTiny(id)) midBlock.y *= 4.0;
    else if (isCeilingRooted(id)) midBlock.y = 1.0 - midBlock.y;
    else if (isTallLower(id)) midBlock.y *= 0.5;
    else if (isTallUpper(id)) midBlock.y = midBlock.y * 0.5 + 0.5;
    else if (isPicherCropLower(id)) midBlock.y = max(midBlock.y * 0.6875 - 0.3125, 0.0);
    else if (isPicherCropUpper(id)) midBlock.y = midBlock.y * 0.6875 + 0.6875 - 0.3125;

    return midBlock;
}
