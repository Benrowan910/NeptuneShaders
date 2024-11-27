#version 460

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

in vec3 vaPosition;
in vec2 vaUV0;

out vec2 fragUV;
out vec3 fragPosition;

uniform float frameTimeCounter;

void main(){

    float waveHeight = 0.1;
    float waveSpeed = 2.0;
    float waveFrequency = 4.0;

    vec3 modifiedPosition = vaPosition;
    modifiedPosition.y += waveHeight * sin(waveFrequency * vaPosition.x + waveSpeed * frameTimeCounter);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(modifiedPosition, 1.0);

    fragUV = vaUV0;
    fragPosition = vaPosition;
}
