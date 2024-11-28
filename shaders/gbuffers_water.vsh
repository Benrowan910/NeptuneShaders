#version 330 compatibility

in vec3 vaPosition;
in vec2 vaUV0;
in vec4 vaColor;

uniform float frameTimeCounter;
uniform sampler2D noisetex;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform vec3 chunkOffset;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

const float waveAmplitude = 0.5;
const float waveFrequency = 1.0;
const float waveSpeed = 1;

void main() {
    vec3 modelPosition = vaPosition + chunkOffset;
    vec3 viewPosition = (modelViewMatrix * vec4((vaPosition + chunkOffset), 1.0)).xyz;
    vec3 normalViewSpace = normalize(viewPosition);
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 worldPosition = feetPlayerPos + cameraPosition;
    vec3 fuck = ftransform().xyz - viewPosition;
  
    //vec4 customOut = projectionMatrix * custom;
    //wave height + noise texture to add some variety
    // float noise = texture(noisetex, vaPosition.xz * 0.1).r;
    // float waveHeight = sin(ftransform().x * waveFrequency + frameTimeCounter * waveSpeed) * waveAmplitude;
    // waveHeight += (noise - 0.5) * waveAmplitude * 0.5;

    float noise = texture(noisetex, fuck.xz * 0.1).r;
    float waveHeight = sin(fuck.x * waveFrequency + frameTimeCounter * waveSpeed) * waveAmplitude;
    waveHeight += (noise - 0.5) * waveAmplitude * 0.5;

    // vec4 displacedPosition = ftransform();
    // displacedPosition.y += waveHeight;
    vec4 displacedPosition = ftransform();
    displacedPosition.y += waveHeight;


    //vec4 viewSpacePositionVec4 = modelViewMatrix * customVertex;
	gl_Position = displacedPosition;
    //gl_Position.y += waveHeight;

	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}
