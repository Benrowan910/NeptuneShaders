// water.glsl - Water-specific utility functions for NeptuneShaders
// Include this file with: #include "lib/water.glsl"
// Requires: #include "lib/common.glsl"

#ifndef WATER_GLSL
#define WATER_GLSL

// ============================================================================
// WATER CONSTANTS
// ============================================================================

const vec3 WATER_SHALLOW = vec3(0.4, 0.8, 1.0);
const vec3 WATER_DEEP = vec3(0.1, 0.3, 0.8);
const vec3 WATER_FOAM = vec3(0.9, 0.95, 1.0);

const float WATER_REFRACTION_INDEX = 1.33;
const float WATER_ABSORPTION_R = 0.45;
const float WATER_ABSORPTION_G = 0.029;
const float WATER_ABSORPTION_B = 0.018;

// ============================================================================
// WAVE GENERATION
// ============================================================================

// Generate simple wave height
float generateWaveHeight(vec2 pos, float time, float intensity) {
    float wave = 0.0;
    
    // Primary waves
    wave += sin(pos.x * 0.1 + time * 0.8) * cos(pos.y * 0.08 + time * 0.6) * intensity;
    
    // Secondary waves
    wave += sin(pos.x * 0.2 + time * 1.2) * cos(pos.y * 0.15 + time * 0.9) * intensity * 0.5;
    
    // Detail waves
    wave += sin(pos.x * 0.5 + time * 2.0) * cos(pos.y * 0.4 + time * 1.5) * intensity * 0.25;
    
    return wave;
}

// Generate wave normal
vec3 generateWaveNormal(vec2 pos, float time, float intensity) {
    const float eps = 0.1;
    
    float heightL = generateWaveHeight(pos - vec2(eps, 0.0), time, intensity);
    float heightR = generateWaveHeight(pos + vec2(eps, 0.0), time, intensity);
    float heightD = generateWaveHeight(pos - vec2(0.0, eps), time, intensity);
    float heightU = generateWaveHeight(pos + vec2(0.0, eps), time, intensity);
    
    vec3 normal = normalize(vec3(
        (heightL - heightR) / (2.0 * eps),
        1.0,
        (heightD - heightU) / (2.0 * eps)
    ));
    
    return normal;
}

// Generate ripples around a point
float generateRipples(vec2 pos, vec2 center, float time, float radius, float intensity) {
    float dist = length(pos - center);
    if (dist > radius) return 0.0;
    
    float ripple = sin(dist * 10.0 - time * 8.0) * exp(-dist / radius);
    return ripple * intensity;
}

// ============================================================================
// WATER PROPERTIES
// ============================================================================

// Calculate water depth color
vec3 calculateWaterDepthColor(float depth) {
    float depthFactor = clamp(depth / 10.0, 0.0, 1.0);
    return mix(WATER_SHALLOW, WATER_DEEP, depthFactor);
}

// Calculate water transparency
float calculateWaterTransparency(float depth, float viewAngle) {
    // Fresnel effect - more transparent when looking straight down
    float fresnel = pow(1.0 - abs(viewAngle), 2.0);
    
    // Depth affects transparency
    float depthFactor = exp(-depth * 0.1);
    
    return mix(0.3, 0.9, fresnel * depthFactor);
}

// Calculate water refraction
vec2 calculateWaterRefraction(vec3 normal, vec3 viewDir, float strength) {
    // Simple refraction offset based on normal
    return normal.xz * strength;
}

// ============================================================================
// WATER REFLECTIONS
// ============================================================================

// Simple sky reflection
vec3 calculateSkyReflection(vec3 reflectDir, vec3 skyColor, vec3 fogColor) {
    float skyFactor = max(0.0, reflectDir.y);
    return mix(fogColor, skyColor, skyFactor);
}

// Calculate Fresnel reflection strength
float calculateFresnelReflection(vec3 normal, vec3 viewDir) {
    float fresnel = dot(normal, viewDir);
    fresnel = 1.0 - abs(fresnel);
    return pow(fresnel, 2.0);
}

// Sun/moon reflection on water
vec3 calculateLightReflection(vec3 reflectDir, vec3 lightDir, vec3 lightColor, float roughness) {
    float alignment = max(dot(reflectDir, lightDir), 0.0);
    float intensity = pow(alignment, 1.0 / (roughness + 0.01));
    return lightColor * intensity * 0.5;
}

// ============================================================================
// WATER FOAM
// ============================================================================

// Generate foam based on wave intensity
float calculateFoam(vec2 pos, float time, float waveIntensity) {
    float foam = 0.0;
    
    // Foam appears where waves are strongest
    float waveHeight = abs(generateWaveHeight(pos, time, waveIntensity));
    if (waveHeight > 0.3) {
        foam = (waveHeight - 0.3) / 0.7;
    }
    
    // Add some noise to foam
    foam *= noise(pos * 5.0 + time);
    
    return clamp(foam, 0.0, 1.0);
}

// Generate shore foam
float calculateShoreFoam(float distanceToShore, float time) {
    if (distanceToShore > 2.0) return 0.0;
    
    float shoreFactor = 1.0 - (distanceToShore / 2.0);
    float wavePattern = sin(time * 3.0) * 0.5 + 0.5;
    
    return shoreFactor * wavePattern;
}

// ============================================================================
// UNDERWATER EFFECTS
// ============================================================================

// Calculate underwater caustics
vec3 calculateUnderwaterCaustics(vec3 worldPos, float time, float intensity) {
    vec2 causticsPos = worldPos.xz * 0.2;
    
    float caustics = 0.0;
    caustics += sin(causticsPos.x * 6.0 + time * 2.0) * cos(causticsPos.y * 4.0 + time * 1.5);
    caustics += sin(causticsPos.x * 10.0 + time * 3.0) * cos(causticsPos.y * 8.0 + time * 2.5) * 0.5;
    
    caustics = max(caustics, 0.0);
    
    return vec3(caustics) * intensity * vec3(0.5, 0.8, 1.0);
}

// Calculate underwater fog
vec3 calculateUnderwaterFog(vec3 color, float depth, vec3 waterColor) {
    float fogFactor = 1.0 - exp(-depth * 0.1);
    return mix(color, waterColor, fogFactor);
}

// Calculate underwater light absorption
vec3 calculateUnderwaterAbsorption(vec3 color, float depth) {
    vec3 absorption = exp(-vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * depth);
    return color * absorption;
}

// ============================================================================
// WATER ANIMATION
// ============================================================================

// Calculate water surface displacement
vec3 calculateWaterDisplacement(vec2 pos, float time, float intensity, float rainStrength) {
    vec3 displacement = vec3(0.0);
    
    // Base waves
    displacement.y = generateWaveHeight(pos, time, intensity);
    
    // Rain effects
    if (isRaining(rainStrength)) {
        // Rain creates more chaotic movement
        displacement.y += noise(pos * 2.0 + time * 5.0) * rainStrength * 0.1;
        
        // Rain ripples
        displacement.y += sin(time * 10.0 + noise(pos * 0.5) * 20.0) * rainStrength * 0.05;
    }
    
    // Calculate horizontal displacement from normal
    vec3 normal = generateWaveNormal(pos, time, intensity);
    displacement.xz = normal.xz * intensity * 0.1;
    
    return displacement;
}

// Calculate flowing water direction
vec2 calculateWaterFlow(vec2 pos, float time, float flowSpeed) {
    // Simple flow pattern
    vec2 flow = vec2(
        sin(pos.y * 0.1 + time * flowSpeed),
        cos(pos.x * 0.1 + time * flowSpeed * 0.8)
    );
    
    return normalize(flow);
}

// ============================================================================
// WATER LIGHTING
// ============================================================================

// Calculate water lighting with subsurface scattering
vec3 calculateWaterLighting(vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor, float depth) {
    // Surface lighting
    float NdotL = max(dot(normal, lightDir), 0.0);
    vec3 surfaceLight = lightColor * NdotL;
    
    // Subsurface scattering
    float backLight = max(dot(-normal, lightDir), 0.0);
    vec3 subsurface = lightColor * backLight * 0.3;
    
    // Depth affects lighting
    float depthFactor = exp(-depth * 0.1);
    
    return (surfaceLight + subsurface) * depthFactor;
}

// Apply water color mixing
vec3 applyWaterColorMixing(vec3 baseColor, vec3 waterColor, float transparency, float depth) {
    // Mix base color with water color based on transparency and depth
    float mixFactor = (1.0 - transparency) * clamp(depth / 5.0, 0.0, 1.0);
    return mix(baseColor, waterColor, mixFactor);
}

#endif // WATER_GLSL