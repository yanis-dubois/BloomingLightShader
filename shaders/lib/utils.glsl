// constant
const float PI = 3.14159265359;
const float e = 2.71828182846;

/* functions */

// -- brdf stuff -- //
float fresnel(vec3 lightDirection, vec3 viewDirection, float reflectance) {
    vec3 H = normalize(lightDirection + viewDirection);
    float VdotH = clamp(dot(viewDirection, H), 0.001, 1.0);

    // fresnel
    float F0 = reflectance;
    return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0); // Schlick's approximation
}
float schlick(float F0, float cosTheta) {
    return F0 + (1 - F0) * pow(1 - cosTheta, 5);
}
float getReflectance(float n1, float n2) {
    float R0 = (n1 - n2) / (n1 + n2);
    return R0 * R0;
}
vec3 brdf(vec3 lightDirection, vec3 viewDirection, vec3 normal, vec3 albedo, float roughness, float reflectance) {
    
    float alpha = pow(roughness, 2);
    vec3 H = normalize(lightDirection + viewDirection);
    
    // dot products
    float NdotV = clamp(dot(normal, viewDirection), 0.001, 1.0);
    float NdotL = clamp(dot(normal, lightDirection), 0.001, 1.0);
    float NdotH = clamp(dot(normal, H), 0.001, 1.0);

    float fresnelReflectance = fresnel(lightDirection, viewDirection, reflectance);

    // geometric attenuation
    float k = alpha/2;
    float geometry = (NdotL / (NdotL * (1-k) + k)) * (NdotV / ((NdotV * (1-k) + k)));

    // microfacets distribution
    float lowerTerm = pow(NdotH,2) * (pow(alpha, 2) - 1.0) + 1.0;
    float normalDistributionFunctionGGX = pow(alpha, 2) / (3.14159 * pow(lowerTerm,2));

    // phong diffuse
    vec3 rhoD = albedo;
    rhoD *= (vec3(1.0) - fresnelReflectance); // energy conservation : light that doesn't reflect adds to diffuse

    vec3 phongDiffuse = rhoD;
    float cookTorrance = (fresnelReflectance * normalDistributionFunctionGGX * geometry) / (4 * NdotL * NdotV);
    vec3 BRDF = NdotL * (phongDiffuse + cookTorrance);
       
    return BRDF;
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
    float theta = zeta1 * 2*PI;
    float radius = sqrt(zeta2);

    // polar to cartesian
    float x = radius * cos(theta);
    float y = radius * sin(theta);

    return vec2(x,y);
}
// sample GGX visible normal (used to reduce noise on GGX sampling)
vec3 sampleGGXVNDF(vec3 Ve, float alpha_x, float alpha_y, float U1, float U2) {

    // transforming the view direction to the hemisphere configuration
    vec3 Vh = normalize(vec3(alpha_x * Ve.x, alpha_y * Ve.y, Ve.z));

    // orthonormal basis (with special case if cross product is zero)
    float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
    vec3 T1 = lensq > 0 ? vec3(-Vh.y, Vh.x, 0) * inversesqrt(lensq) 
                        : vec3(1,0,0);
    vec3 T2 = cross(Vh, T1);

    // parameterization of the projected area
    float r = sqrt(U1);
    float phi = 2.0 * PI * U2;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s)*sqrt(1.0 - t1*t1) + s*t2;

    // reprojection onto hemisphere
    vec3 Nh = t1*T1 + t2*T2 + sqrt(max(0.0, 1.0 - t1*t1 - t2*t2))*Vh;

    // transforming the normal back to the ellipsoid configuration
    vec3 Ne = normalize(vec3(alpha_x * Nh.x, alpha_y * Nh.y, max(0.0, Nh.z)));

    return Ne;
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

// -- misc -- //
float distance1(vec2 p1, vec2 p2) {
    return abs(p2.x - p1.x) + abs(p2.y - p1.y);
}
float distanceInf(vec2 p1, vec2 p2) {
    return max(abs(p2.x - p1.x), abs(p2.y - p1.y));
}
float distanceInf(vec3 p1, vec3 p2) {
    return max(distanceInf(p1.xy, p2.xy), abs(p2.z - p1.z));
}
float perspectiveMix(float a, float b, float factor) {
    return 1. / ( (1./a) + (factor * ((1./b) - (1./a))) );
}
float gaussian(float x, float y, float mu, float sigma) {
    return exp(- (((x-mu)*(x-mu) + (y-mu)*(y-mu)) / (2*sigma*sigma)));
}
float gaussian(float x, float mu, float sigma) {
    return exp(- (((x-mu)*(x-mu)) / (2*sigma*sigma)));
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
    return pow(x, 1./gamma);
}
vec2 linearToSRGB(vec2 x) {
    return pow(x, vec2(1./gamma));
}
vec3 linearToSRGB(vec3 x) {
    return pow(x, vec3(1./gamma));
}
vec4 linearToSRGB(vec4 x) {
    return pow(x, vec4(1./gamma));
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
        if (t > 0) {
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
            if (dot(-planes_normal[j], intersections[i] - planes_point[j]) < 0) {
                isInside = false;
                break;
            }
        }

        if (isInside) {
            return intersections[i];
        }
    }

    return vec3(0);
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
    ambiant_occlusion = 1 - map(lightData.w, 0.5, 1, 0, 1);
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
    return id == 20000;
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

    midBlock.y = -1 * midBlock.y + 0.5;
    if (isSmall(id)) midBlock.y *= 2;
    else if (isTiny(id)) midBlock.y *= 4;
    else if (isCeilingRooted(id)) midBlock.y = 1 - midBlock.y;
    else if (isTallLower(id)) midBlock.y *= 0.5;
    else if (isTallUpper(id)) midBlock.y = midBlock.y * 0.5 + 0.5;
    else if (isPicherCropLower(id)) midBlock.y = max(midBlock.y * 0.6875 - 0.3125, 0);
    else if (isPicherCropUpper(id)) midBlock.y = midBlock.y * 0.6875 + 0.6875 - 0.3125;

    return midBlock;
}
