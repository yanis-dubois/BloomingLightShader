#ifndef "/lib/common.glsl"
#define "/lib/common.glsl"

// constant
const float PI = 3.14159265359;
const float e = 2.71828182846;

/* functions */

float schlick(float n2, float cosTheta) {
    float n1 = 1;
    float R0_ = ((n1 - n2) / (n1 + n2));
    float R0 = R0_ * R0_;
    return R0 + (1 - R0) * pow(1 - cosTheta, 5);
}

bool isInRange(float x, float min_, float max_) {
    return min_ < x && x < max_;
}

bool isInRange(vec2 xy, float min_, float max_) {
    return isInRange(xy.x, min_, max_) && isInRange(xy.y, min_, max_);
}

float map(float value, float fromMin, float fromMax, float toMin, float toMax) {
    // to [0;1]
    float mapped = (value-fromMin) / (fromMax-fromMin);
    // to new interval
    return mapped*(toMax-toMin) + toMin;
}

float perspectiveMix(float a, float b, float factor) {
    return 1. / ( (1./a) + (factor * ((1./b) - (1./a))) );
}

float sigmoid(float x, float offset, float speed) {
    return (offset / (offset + pow(e, -speed * x)));
}

float normalDistribution(float x, float y, float mu, float sigma) {
    return exp(-(x-mu)*(x-mu) / 2*sigma*sigma) / sqrt(PI*sigma*sigma);
}

float cosThetaToSigmoid(float cosTheta, float offset, float speed) {
    float normalizedAngle = acos(cosTheta)/PI *4 -1;
    return 1 - sigmoid(normalizedAngle, offset, speed);
}

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

#endif
