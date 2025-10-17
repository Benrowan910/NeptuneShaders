#version 330 compatibility

// Uniforms
uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform float alphaTestRef = 0.1;

// Inputs from vertex shader
in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPos;
in vec3 viewPos;
in vec3 normal;
in float waveIntensity;
in float waterBodySize;

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Constants
const vec3 WATER_COLOR_SHALLOW = vec3(0.4, 0.8, 1.0);
const vec3 WATER_COLOR_DEEP = vec3(0.1, 0.3, 0.6);
const float WATER_TRANSPARENCY = 0.8;
const float REFRACTION_STRENGTH = 0.02;

// Noise function for detailed wave normals
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

// Generate detailed surface normals
vec3 getWaveNormal(vec2 pos, float time, float intensity) {
    float epsilon = 0.01;
    
    // Sample height at current position and nearby points
    float h = noise(pos * 8.0 + time * 2.0) * intensity;
    float hx = noise((pos + vec2(epsilon, 0.0)) * 8.0 + time * 2.0) * intensity;
    float hy = noise((pos + vec2(0.0, epsilon)) * 8.0 + time * 2.0) * intensity;
    
    // Calculate gradients
    float dx = (hx - h) / epsilon;
    float dy = (hy - h) / epsilon;
    
    // Generate normal
    return normalize(vec3(-dx, 1.0, -dy));
}

// Fresnel calculation
float fresnel(vec3 viewDir, vec3 normal, float ior) {
    float cosTheta = max(0.0, dot(-viewDir, normal));
    float r0 = (1.0 - ior) / (1.0 + ior);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow(1.0 - cosTheta, 5.0);
}

// Blinn-Phong specular calculation
float blinnPhong(vec3 lightDir, vec3 viewDir, vec3 normal, float shininess) {
    vec3 halfVector = normalize(lightDir - viewDir);
    float NdotH = max(0.0, dot(normal, halfVector));
    return pow(NdotH, shininess);
}

// Simple reflection simulation
vec3 getReflectionColor(vec3 normal, vec3 viewDir) {
    vec3 reflectDir = reflect(viewDir, normal);
    
    // Simple sky reflection based on direction
    float skyFactor = max(0.0, reflectDir.y);
    vec3 skyReflection = mix(fogColor, skyColor, skyFactor);
    
    // Add some variation based on time
    float timeVariation = sin(frameTimeCounter * 0.5) * 0.1 + 0.9;
    return skyReflection * timeVariation;
}

void main() {
    // Get base water color
    vec4 baseColor = texture(gtexture, texcoord) * glcolor;
    
    // Calculate detailed surface normal
    vec3 detailNormal = getWaveNormal(worldPos.xz, frameTimeCounter, waveIntensity * 0.5);
    vec3 surfaceNormal = normalize(normal + detailNormal * 0.3);
    
    // View direction
    vec3 viewDir = normalize(viewPos);
    
    // Light direction (sun during day, moon during night)
    bool isDay = worldTime > 1000 && worldTime < 13000;
    vec3 lightPos = isDay ? sunPosition : moonPosition;
    vec3 lightDir = normalize(lightPos);
    
    // Water depth approximation
    float depth = length(viewPos) * 0.01;
    depth = clamp(depth, 0.0, 1.0);
    
    // Water color mixing based on depth and body size
    vec3 waterColor = mix(WATER_COLOR_SHALLOW, WATER_COLOR_DEEP, depth * waterBodySize);
    
    // Fresnel effect
    float fresnelFactor = fresnel(viewDir, surfaceNormal, 1.33); // Water IOR ≈ 1.33
    
    // Reflection
    vec3 reflectionColor = getReflectionColor(surfaceNormal, viewDir);
    
    // Specular highlights (Blinn-Phong)
    float shininess = 128.0 * (1.0 + waveIntensity);
    float specular = blinnPhong(lightDir, viewDir, surfaceNormal, shininess);
    
    // Weather effects
    float stormDarkening = 1.0 - rainStrength * 0.3;
    waterColor *= stormDarkening;
    
    // Combine colors
    vec3 finalColor = mix(waterColor, reflectionColor, fresnelFactor * 0.8);
    finalColor += specular * vec3(1.0, 1.0, 0.9) * (isDay ? 1.0 : 0.3);
    
    // Apply lighting
    vec3 lightmapColor = texture(lightmap, lmcoord).rgb;
    finalColor *= lightmapColor;
    
    // Calculate final alpha
    float alpha = WATER_TRANSPARENCY + fresnelFactor * 0.2;
    alpha = clamp(alpha, 0.3, 0.95);
    
    color = vec4(finalColor, alpha);
    
    if (color.a < alphaTestRef) {
        discard;
    }
}