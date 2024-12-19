#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"

#pragma glslify: snoise3 = require(/ext/glsl-noise/simplex/3d)
#pragma glslify: snoise4 = require(/ext/glsl-noise/simplex/4d)

// attributes
// gl_MultiTexCoord0.xy - block and item texture coordinate
// gl_MultiTexCoord2.xy - lightmap coordinate
in vec3 mc_Entity;
in vec3 at_midBlock;

// results
out vec4 additionalColor;
out vec3 normal;
out vec3 viewSpacePosition;
out vec2 textureCoordinate;
out vec2 lightMapCoordinate;
flat out int id;

void main() {
    // color & light infos //
    textureCoordinate = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightMapCoordinate = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    additionalColor = gl_Color;
    //additionalColor = vec4((gl_Vertex.xyz + at_midBlock)/16, 1);

    // geometry infos //
    // normal
    normal = normalize(gl_NormalMatrix * gl_Normal);
    normal = mat3(gbufferModelViewInverse) * normal; // from view to world space

    id = int(mc_Entity.x);
    
    // depth
    vec4 viewPosition = (gl_ModelViewMatrix * gl_Vertex); // from player to view space
    viewSpacePosition = viewPosition.xyz;

    gl_Position = ftransform();

    // vertex movement (see later)
    if (id == 20000) {
        vec3 objectPosition = gl_Vertex.xyz + at_midBlock;
        vec4 worldSpacePosition = ( (gbufferModelViewInverse) * viewPosition) + vec4(cameraPosition, 0);

        float phi = float(worldTime)/10 + worldSpacePosition.z;
        float freq = 2;
        float amp = 0.1;

        //amp *= map(objectPosition.y, -32.0, 32.0, 1.0, 0.0);

        worldSpacePosition.y += amp * sin(phi + 2*PI*freq);

        viewPosition = (gbufferModelView * (worldSpacePosition - vec4(cameraPosition, 0)));
        viewSpacePosition = viewPosition.xyz;

        gl_Position = gl_ProjectionMatrix * viewPosition; // to clip space
    }
}
