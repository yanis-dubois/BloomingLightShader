float getReflectance(float n1, float n2) {
    float R0 = (n1 - n2) / (n1 + n2);
    return R0 * R0;
}

vec3 schlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float schlick(float cosTheta, float F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float fresnel(vec3 viewDirection, vec3 normal, float reflectance) {
    float VdotN = clamp(dot(viewDirection, normal), 0.001, 1.0);
    return schlick(VdotN, reflectance);
}

// GGX normal distribution function
float GGXNDF(float NdotH, float roughness) {
    float alpha = roughness * roughness;
    float alpha2 = alpha * alpha;
    float denom = (NdotH * NdotH * (alpha2 - 1.0) + 1.0);
    return alpha2 / (PI * denom * denom);
}

// Smith GGX geometry function
float Smith_G(float NdotV, float NdotL, float roughness) {
    float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    float G_V = NdotV / (NdotV * (1.0 - k) + k);
    float G_L = NdotL / (NdotL * (1.0 - k) + k);
    return G_V * G_L;
}

// Cook Torrance BRDF
vec3 CookTorranceBRDF(vec3 N, vec3 V, vec3 L, vec3 albedo, float smoothness, float reflectance) {
    float roughness = 1.0 - smoothness;

    vec3 H = normalize(V + L);

    float NdotV = dot(N, V);
    float NdotL = dot(N, L);
    float NdotH = dot(N, H);
    float VdotH = dot(V, H);
    float LdotH = dot(L, H);

    NdotV = max(NdotV, 0.001);
    NdotL = max(NdotL, 0.001);
    NdotH = max(NdotH, 0.001);
    VdotH = max(VdotH, 0.001);
    LdotH = max(LdotH, 0.001);

    float D = GGXNDF(NdotH, roughness);
    float F = schlick(LdotH, reflectance);
    float G = Smith_G(VdotH, LdotH, roughness);

    vec3 specularColor = saturate(albedo, 1.3);
    specularColor = albedo;
    specularColor = mix(specularColor, vec3(1.0), 0.05);

    return specularColor * (D * F * G) / (4.0 * VdotH * LdotH + 0.001);

    // not used
    // vec3 diffuse = albedo * (1.0 - F) * (1.0 / PI);
    // return diffuse + specular;
}

// subsurface BRDF (not even close to reality)
vec3 specularSubsurfaceBRDF(vec3 V, vec3 L, vec3 albedo) {
    float VdotL = dot(V, - L);
    VdotL = max(VdotL, 0.0);

    vec3 transmittedColor = saturate(albedo, VdotL * 1.4);
    transmittedColor = mix(transmittedColor, vec3(1.0), 0.05);

    vec3 specular = transmittedColor * pow(VdotL, 8.0) * 5.0;
    return specular;
}

// sample GGX visible normal (cf. Journal of Computer Graphics Techniques Vol. 7, No. 4, 2018)
vec3 sampleGGXVNDF(vec3 Ve, float alpha_x, float alpha_y, float U1, float U2) {

    // transforming the view direction to the hemisphere configuration
    vec3 Vh = normalize(vec3(alpha_x * Ve.x, alpha_y * Ve.y, Ve.z));

    // orthonormal basis (with special case if cross product is zero)
    float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
    vec3 T1 = lensq > 0.0 ? vec3(-Vh.y, Vh.x, 0.0) * inversesqrt(lensq) 
                        : vec3(1.0, 0.0, 0.0);
    vec3 T2 = cross(Vh, T1);

    // parameterization of the projected area
    float r = sqrt(U1);
    float phi = 2.0 * PI * U2;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s) * sqrt(1.0 - t1*t1) + s*t2;

    // reprojection onto hemisphere
    vec3 Nh = t1*T1 + t2*T2 + sqrt(max(0.0, 1.0 - t1*t1 - t2*t2)) * Vh;

    // transforming the normal back to the ellipsoid configuration
    vec3 Ne = normalize(vec3(alpha_x * Nh.x, alpha_y * Nh.y, max(0.0, Nh.z)));

    return Ne;
}
