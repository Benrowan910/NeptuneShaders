#version 460

in vec3 vaPosition;

in vec2 vaUV;

uniform vec3 chunkOffset;
uniform mat4 MVM;
uniform mat4 pMatrix;

out vec2 texCoord;

void main(){

    texCoord = vaUV;

    gl_Position = pMatrix * MVM * vec4(vaPosition + chunkOffset, 1);
}