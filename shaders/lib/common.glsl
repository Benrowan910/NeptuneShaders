// common.glsl - Shared utility functions for NeptuneShaders
// Include this file in other shaders with: #include "lib/common.glsl"

#ifndef COMMON_GLSL
#define COMMON_GLSL

// ============================================================================
// TIME AND WEATHER UTILITIES
// ============================================================================

// Check if it's daytime
bool isDay(int worldTime) {
    return worldTime > 1000 && worldTime < 13000;
}

// Check if it's night
bool isNight(int worldTime) {
    return worldTime >= 13000 || worldTime <= 1000;
}

// Get normalized time of day (0.0 = midnight, 0.5 = noon)
float getTimeOfDay(int worldTime) {
    return float(worldTime) / 24000.0;
}

// Get day progress (0.0 = sunrise, 1.0 = sunset)
float getDayProgress(int worldTime) {
    if (!isDay(worldTime)) return 0.0;
    return (float(worldTime) - 1000.0) / 12000.0;
}

// Check if it's sunrise (5000-7000 worldTime)
bool isSunrise(int worldTime) {
    return worldTime > 5000 && worldTime < 7000;
}

// Check if it's sunset (17000-19000 worldTime)
bool isSunset(int worldTime) {
    return worldTime > 17000 && worldTime < 19000;
}

// Check if it's raining
bool isRaining(float rainStrength) {
    return rainStrength > 0.1;
}

// Get storm intensity (0.0 = no rain, 1.0 = heavy rain)
float getStormIntensity(float rainStrength) {
    return clamp(rainStrength, 0.0, 1.0);
}

// ============================================================================
// COLOR UTILITIES
// ============================================================================

// Calculate luminance of a color
float getLuminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

// Desaturate a color
vec3 desaturate(vec3 color, float amount) {
    float luminance = getLuminance(color);
    return mix(color, vec3(luminance), amount);
}

// Simple gamma correction
vec3 applyGamma(vec3 color, float gamma) {
    return pow(color, vec3(1.0 / gamma));
}

// Enhance color contrast
vec3 enhanceContrast(vec3 color, float contrast) {
    return mix(vec3(0.5), color, contrast);
}

// ============================================================================
// LIGHTING UTILITIES
// ============================================================================

// Get light direction based on time of day
vec3 getLightDirection(vec3 sunPosition, vec3 moonPosition, int worldTime) {
    return isDay(worldTime) ? normalize(sunPosition) : normalize(moonPosition);
}

// Get light color based on time of day
vec3 getLightColor(int worldTime, float rainStrength) {
    vec3 lightColor;
    
    if (isDay(worldTime)) {
        if (isSunrise(worldTime) || isSunset(worldTime)) {
            // Warm sunrise/sunset
            lightColor = vec3(1.0, 0.7, 0.4);
        } else {
            // Normal daylight
            lightColor = vec3(1.0, 1.0, 0.95);
        }
    } else {
        // Moonlight
        lightColor = vec3(0.3, 0.35, 0.5);
    }
    
    // Reduce light during rain
    if (isRaining(rainStrength)) {
        lightColor *= (1.0 - rainStrength * 0.4);
    }
    
    return lightColor;
}

// Simple Blinn-Phong lighting calculation
vec3 calculateBlinnPhong(vec3 albedo, vec3 normal, vec3 lightDir, vec3 viewDir, vec3 lightColor, float roughness) {
    float NdotL = max(dot(normal, lightDir), 0.0);
    
    // Diffuse
    vec3 diffuse = albedo * lightColor * NdotL;
    
    // Specular
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfDir), 0.0);
    float shininess = 1.0 / (roughness * roughness + 0.01);
    float specular = pow(NdotH, shininess) * (1.0 - roughness);
    
    return diffuse + lightColor * specular * 0.2;
}

// ============================================================================
// NOISE AND RANDOM UTILITIES
// ============================================================================

// Simple random function
float random(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Simple 2D noise
float noise(vec2 pos) {
    vec2 i = floor(pos);
    vec2 f = fract(pos);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// ============================================================================
// MATERIAL DETECTION
// ============================================================================

// Check if a color represents foliage (greenish)
bool isFoliage(vec3 color) {
    return (color.g > color.r && color.g > color.b && color.g > 0.3);
}

// Check if a color represents metallic material (grayish with high brightness)
bool isMetallic(vec3 color) {
    float brightness = getLuminance(color);
    return (abs(color.r - color.g) < 0.1 && abs(color.g - color.b) < 0.1 && brightness > 0.4);
}

// Check if a color represents gold (yellowish)
bool isGold(vec3 color) {
    return (color.r > 0.6 && color.g > 0.5 && color.b < 0.4 && color.r > color.g && color.g > color.b);
}

// Check if a color represents water (blueish or transparent)
bool isWater(vec3 color, float alpha) {
    return (alpha < 0.9) || (color.b > color.r && color.b > color.g);
}

// ============================================================================
// ANIMATION UTILITIES
// ============================================================================

// Simple sine wave animation
float sineWave(float time, float frequency, float amplitude, float offset) {
    return sin(time * frequency + offset) * amplitude;
}

// Smooth animation curve (ease in/out)
float smoothCurve(float t) {
    return t * t * (3.0 - 2.0 * t);
}

// Pulsing animation
float pulse(float time, float frequency, float minValue, float maxValue) {
    float wave = sin(time * frequency) * 0.5 + 0.5;
    return mix(minValue, maxValue, wave);
}

// ============================================================================
// WEATHER EFFECTS
// ============================================================================

// Apply rain darkening to colors
vec3 applyRainDarkening(vec3 color, float rainStrength) {
    if (!isRaining(rainStrength)) return color;
    
    // Darken and desaturate during rain
    color *= (1.0 - rainStrength * 0.3);
    color = desaturate(color, rainStrength * 0.4);
    
    // Add slight blue tint
    color *= vec3(0.9, 0.95, 1.1);
    
    return color;
}

// Get wind strength based on weather
float getWindStrength(float rainStrength, float baseStrength) {
    return baseStrength * (1.0 + rainStrength * 2.0);
}

// ============================================================================
// COORDINATE TRANSFORMATIONS
// ============================================================================

// Convert world position to screen space
vec2 worldToScreen(vec3 worldPos, mat4 modelView, mat4 projection) {
    vec4 clipPos = projection * modelView * vec4(worldPos, 1.0);
    return (clipPos.xy / clipPos.w) * 0.5 + 0.5;
}

// Convert screen position to world space
vec3 screenToWorld(vec2 screenPos, float depth, mat4 invProjection, mat4 invModelView) {
    vec4 ndcPos = vec4(screenPos * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = invProjection * ndcPos;
    viewPos /= viewPos.w;
    vec4 worldPos = invModelView * viewPos;
    return worldPos.xyz;
}

// ============================================================================
// UTILITY CONSTANTS
// ============================================================================

// Common shader constants
const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float EPSILON = 0.001;

// Minecraft time constants
const int SUNRISE_START = 5000;
const int SUNRISE_END = 7000;
const int DAY_START = 1000;
const int DAY_END = 13000;
const int SUNSET_START = 17000;
const int SUNSET_END = 19000;

// Common color values
const vec3 WATER_COLOR_SHALLOW = vec3(0.4, 0.8, 1.0);
const vec3 WATER_COLOR_DEEP = vec3(0.1, 0.3, 0.8);
const vec3 GRASS_COLOR_ENHANCE = vec3(0.95, 1.1, 0.95);
const vec3 GOLD_COLOR = vec3(1.0, 0.86, 0.57);

#endif // COMMON_GLSL