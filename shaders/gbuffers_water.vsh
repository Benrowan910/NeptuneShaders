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

// Wave generation functions
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
    wave += sin(pos.x * 0.02 + time * 2.0) * 0.5;
    wave += sin(pos.x * 0.03 + pos.y * 0.015 + time * 1.7) * 0.3;
    wave += noise(pos * 0.05 + time * 0.5) * 0.2;
    wave += noise(pos * 0.1 + time * 0.8) * 0.1;
    return wave * intensity;
}

// Estimate water body size based on nearby vertices
float estimateWaterBodySize(vec3 pos) {
    // Simple heuristic: larger Y values or positions far from spawn suggest ocean
    float distanceFromSpawn = length(pos.xz);
    float yLevel = pos.y;
    
    // Ocean typically at y=63, rivers/ponds at various levels
    if (yLevel > 60.0 && yLevel < 65.0 && distanceFromSpawn > 100.0) {
        return 1.0; // Large body (ocean)
    } else if (distanceFromSpawn > 50.0) {
        return 0.7; // Medium body (lake)
    } else {
        return 0.3; // Small body (pond/river)
    }
}

void main() {
    // Use standard transformation
    gl_Position = ftransform();
    
    // Basic outputs for water
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    
    // Simple world position calculation
    worldPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    
    // Simple wave parameters
    waveIntensity = 0.5;
    waterBodySize = 1.0;
}