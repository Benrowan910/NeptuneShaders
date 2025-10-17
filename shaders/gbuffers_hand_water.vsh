#version 330 compatibility

// Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform float frameTimeCounter;
uniform int worldTime;
uniform float rainStrength;
uniform vec3 cameraPosition;

// Attributes
attribute vec4 mc_Entity;
attribute vec3 mc_midTexCoord;

// Outputs
out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 worldPos;
out vec3 viewPos;
out vec3 normal;
out float waveIntensity;
out float waterBodySize;

// Wave generation functions (simplified for hand water)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float waves(vec2 pos, float time, float intensity) {
    float wave = 0.0;
    // Gentler waves for hand water
    wave += sin(pos.x * 0.1 + time * 1.5) * 0.3;
    wave += sin(pos.x * 0.15 + pos.y * 0.1 + time * 1.2) * 0.2;
    wave += noise(pos * 0.2 + time * 0.3) * 0.1;
    return wave * intensity;
}

void main() {
    // Transform to world space
    vec4 worldPosition = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    worldPos = worldPosition.xyz + cameraPosition;
    
    // Hand water is always small body
    waterBodySize = 0.2;
    
    // Reduced wave intensity for hand water
    float stormFactor = rainStrength * 1.5 + 0.3;
    float timeFactor = (sin(worldTime * 0.001) + 1.0) * 0.5;
    waveIntensity = stormFactor * waterBodySize * (0.3 + timeFactor * 0.3);
    
    // Generate gentle waves
    float time = frameTimeCounter;
    float waveHeight = waves(worldPos.xz, time, waveIntensity * 0.1);
    
    // Apply wave displacement (very subtle)
    vec4 displacedPosition = worldPosition;
    displacedPosition.y += waveHeight;
    
    // Transform back to clip space
    vec4 viewPosition = gbufferModelView * (displacedPosition - vec4(cameraPosition, 0.0));
    viewPos = viewPosition.xyz;
    gl_Position = gbufferProjection * viewPosition;
    
    // Calculate normal for waves
    float epsilon = 0.05;
    float heightX = waves(worldPos.xz + vec2(epsilon, 0.0), time, waveIntensity * 0.1);
    float heightZ = waves(worldPos.xz + vec2(0.0, epsilon), time, waveIntensity * 0.1);
    
    vec3 tangentX = normalize(vec3(epsilon, heightX - waveHeight, 0.0));
    vec3 tangentZ = normalize(vec3(0.0, heightZ - waveHeight, epsilon));
    normal = normalize(cross(tangentX, tangentZ));
    
    // Pass through texture coordinates and lighting
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
}