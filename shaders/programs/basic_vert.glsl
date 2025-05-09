#version 460

in vec3 vaPosition;
in vec2 vaUV0;
in vec4 vaColor;

uniform mat4 modelViewMatrix;;
uniform mat4 projectionMatrix;;

uniform vec3 chunkOffset;

out vec2 texCoord;
out vec3 foliageColor;

void main(){
    texCoord = vaUV0;

    foliageColor = vaColor.rgb;

    vec4 viewSpacePositionVec4 = modelViewMatrix * vec4(vaPosition + chunkOffset, 1);

    gl_Position = projectionMatrix * viewSpacePositionVec4;
}