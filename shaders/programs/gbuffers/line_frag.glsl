#extension GL_ARB_explicit_attrib_location : enable

// attributes
in vec4 albedo;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;

void main() {
    colorData = vec4(albedo);
}
