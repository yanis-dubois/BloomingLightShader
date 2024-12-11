#ifndef "/lib/common.glsl"
#define "/lib/common.glsl"

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
vec3 getNoise(vec2 uv) {
    ivec2 screenCoord = ivec2(uv * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
    ivec2 noiseCoord = screenCoord % noiseTextureResolution; // wrap to range of noiseTextureResolution
    return texelFetch(noisetex, noiseCoord, 0).rgb;
}

// -- interval stuff -- //
bool isInRange(float x, float min_, float max_) {
    return min_ < x && x < max_;
}
bool isInRange(vec2 xy, float min_, float max_) {
    return isInRange(xy.x, min_, max_) && isInRange(xy.y, min_, max_);
}
float map(float value, float fromMin, float fromMax, float toMin, float toMax) {
    float mapped = (value-fromMin) / (fromMax-fromMin); // from [fromMin;fromMax] to [0;1]
    return mapped*(toMax-toMin) + toMin; // from [0;1] to [toMin;toMax]
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
float cosThetaToSigmoid(float cosTheta, float offset, float speed) {
    float normalizedAngle = acos(cosTheta)/PI *4 -1;
    return 1 - sigmoid(normalizedAngle, offset, speed);
}

// -- color stuff -- //
vec3 kelvinToRGB(float kelvin) {
    // Normalize the Kelvin value to fit the range.
    float temperature = kelvin / 100.;

    // Initialize RGB values
    float red, green, blue;

    // Calculate red
    if (temperature <= 66.) {
        red = 1.;
    } else {
        red = temperature - 60.;
        red = 329.698727446 * pow(red, -0.1332047592);
        red = clamp(min(255., red), 0, 255) / 255.;
    }

    // Calculate green
    if (temperature <= 66.) {
        green = temperature;
        green = 99.4708025861 * log(green) - 161.1195681661;
    } else {
        green = temperature - 60.;
        green = 288.1221695283 * pow(green, -0.0755148492);
    }
    green = clamp(min(255., green), 0, 255) / 255.;

    // Calculate blue
    if (temperature >= 66.) {
        blue = 1.;
    } else {
        if (temperature <= 19.) {
            blue = 0.;
        } else {
            blue = temperature - 10.;
            blue = 138.5177312231 * log(blue) - 305.0447927307;
            blue = clamp(min(255., blue), 0, 255) / 255.;
        }
    }

    return vec3(red, green, blue);
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
    return (normal + 1) / 2; // from [-1;1] to [0;1]
}
vec3 decodeNormal(vec3 normal) {
    return normal * 2 - 1; // from [0;1] to [-1;1]
}

#endif
