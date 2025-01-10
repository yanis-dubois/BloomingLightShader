#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"

// textures
uniform sampler2D colortex0; // color
uniform sampler2D depthtex0; // all depth
uniform sampler2D shadowtex0; // all shadow
uniform sampler2D shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 color = texture2D(colortex0, uv);

    color.rgb = SRGBtoLinear(color.rgb);

    // float depth = texture2D(depthtex0, uv).r;
    // vec3 worldSpacePosition = screenToWorld(uv, depth);
    // float distanceFromCamera = distance(viewToWorld(vec3(0)), worldSpacePosition);

    // if (depth < 1) {
    //     float radius = distanceFromCamera / 10;
    //     float samples = 20.0;
    //     float step_length = radius/samples;
    //     vec3 c = vec3(0);
    //     float count = 0;
    //     for (float x=-radius; x<=radius; x+=step_length) {
    //         for (float y=-radius; y<=radius; y+=step_length) {
    //             vec2 coord = vec2(x,y);
    //             coord = uv + texelToScreen(coord);

    //             float depth_ = texture2D(depthtex0, coord).r;
    //             vec3 worldSpacePosition_ = screenToWorld(coord, depth_);
    //             float distanceFromCamera_ = distance(viewToWorld(vec3(0)), worldSpacePosition_);
    //             if (abs(distanceFromCamera_ - distanceFromCamera) > 15) 
    //                 continue;

    //             float weight = gaussian(x, y, 0, 1);
    //             c += weight * SRGBtoLinear(texture2D(colortex0, coord).rgb);
    //             count += weight;
    //         }
    //     }
    //     color.rgb = c / count;
    // }

    color.rgb = linearToSRGB(color.rgb);

    outColor = color;

    // outColor = texture2D(shadowcolor0, uv);
}
