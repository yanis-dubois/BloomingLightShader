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

// -- random generator -- //
// return 3 random value from uv coordinates
float pseudoRandom(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}
// vec3 getNoise(vec2 uv) {
//     ivec2 screenCoord = ivec2(uv * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
//     ivec2 noiseCoord = screenCoord % noiseTextureResolution; // wrap to range of noiseTextureResolution
//     return texelFetch(noisetex, noiseCoord, 0).rgb;
// }
// vec3 getNoise(vec2 uv, float seed) {
//     float rand = pseudoRandom(vec2(seed));
//     uv += rand;
//     ivec2 screenCoord = ivec2(uv * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
//     ivec2 noiseCoord = screenCoord % noiseTextureResolution; // wrap to range of noiseTextureResolution
//     return texelFetch(noisetex, noiseCoord, 0).rgb;
// }
// // sample GGX normal
// vec3 sampleGGXNormal(vec2 uv, float alpha) {
//     vec2 zeta = getNoise(uv).xy;

//     // Étape 1 : Calcul de θ_h et φ_h
//     float theta_h = atan(alpha * sqrt(zeta.x) / sqrt(1.0 - zeta.x));
//     float phi_h = 2.0 * PI * zeta.y;

//     // Étape 2 : Conversion en coordonnées cartésiennes
//     vec3 h_local;
//     h_local.x = sin(theta_h) * cos(phi_h);
//     h_local.y = sin(theta_h) * sin(phi_h);
//     h_local.z = cos(theta_h);

//     return h_local;
// }
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
float perspectiveMix(float a, float b, float factor) {
    return 1. / ( (1./a) + (factor * ((1./b) - (1./a))) );
}
float sigmoid(float x, float offset, float speed) {
    return (offset / (offset + pow(e, -speed * x)));
}
float sigmoid(float x, float offset, float speed, float translation) {
    return (offset / (offset + pow(e, -speed * (x + translation))));
}
float cosThetaToSigmoid(float cosTheta, float offset, float speed, float duration) {
    float normalizedAngle = duration * acos(cosTheta)/PI *4 -1;
    return 1 - sigmoid(normalizedAngle, offset, speed);
}
float gaussian(float x, float y, float mu, float sigma) {
    return exp(- (((x-mu)*(x-mu) + (y-mu)*(y-mu)) / (2*sigma*sigma)));
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

    //type = SRGBtoLinear(type);
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
bool isWater(float type) {
    return areNearlyEqual(type, typeWater);
}
bool isLit(float type) {
    return areNearlyEqual(type, typeLit);
}

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
    return isUnderGrowth(id) && id != 10021;
}
// root type
bool isCeilingRooted(int id) {
    return id == 10020;
}
bool isTallLower(int id) {
    return id == 10010 || id == 10051;
}
bool isTallUpper(int id) {
    return id == 10011 || id == 10052;
}
bool isPicherCropLower(int id) {
    return id == 10002;
}
bool isPicherCropUpper(int id) {
    return id == 10003;
}
// subsurface 
bool isColumnSubsurface(int id) {
    return id == 10021 || id == 10055 || id == 10060;
}
bool isCobweb(int id) {
    return id == 10070;
}

// offset midBlock coordinate to make the root of foliage the origin
vec3 midBlockToRoot(int id, vec3 midBlock) {
    midBlock /= 64.0;

    midBlock.y = -1 * midBlock.y + 0.5;
    if (isCeilingRooted(id)) midBlock.y = 1 - midBlock.y;
    else if (isTallLower(id)) midBlock.y *= 0.5;
    else if (isTallUpper(id)) midBlock.y = midBlock.y * 0.5 + 0.5;
    else if (isPicherCropLower(id)) midBlock.y = max(midBlock.y * 0.5 - 0.3125, 0);
    else if (isPicherCropUpper(id)) midBlock.y = midBlock.y * 0.5 + 0.5 - 0.3125;

    return midBlock;
}
