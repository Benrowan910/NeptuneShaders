#version 330 compatibility

#include "lib/common.glsl"
#include "lib/lighting.glsl"

// Uniforms
uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float alphaTestRef = 0.1;

// Inputs from vertex shader
in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPos;
in vec3 viewPos;
in vec3 normal;
in float blockId;
in float foliageType;

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    // Get base color - this should be preserved!
    vec4 albedoColor = texture(gtexture, texcoord) * glcolor;
    
    // Sample lightmap safely - vanilla Minecraft approach
    vec3 lightmapColor = texture(lightmap, clamp(lmcoord, 0.0, 1.0)).rgb;
    
    // Setup basic lighting vectors
    vec3 surfaceNormal = normalize(normal);
    vec3 lightDir = getLightDirection(sunPosition, moonPosition, worldTime);
    vec3 lightColor = getLightColor(worldTime, rainStrength);
    
    // Calculate simple directional lighting factor (vanilla-style)
    float NdotL = max(dot(surfaceNormal, lightDir), 0.0);
    float directionalFactor = mix(0.6, 1.0, NdotL); // Soft directional influence
    
    // Vanilla-style lighting: multiply base color by lighting factors
    vec3 finalColor = albedoColor.rgb;
    
    // Special handling for foliage to maintain color
    if (foliageType > 0.5) {
        finalColor *= GRASS_COLOR_ENHANCE; // Subtle grass enhancement
    }
    
    // Apply lightmap (this is the core of vanilla lighting)
    finalColor *= lightmapColor.x; // Sky light
    finalColor *= lightmapColor.y; // Block light
    
    // Apply directional lighting
    finalColor *= directionalFactor;
    
    // Apply time-of-day lighting color
    finalColor *= lightColor;
    
    // Add minimal atmospheric effects while preserving vanilla feel
    float distance = length(viewPos);
    if (distance > 16.0) {
        float atmosphereFactor = min(1.0 - exp(-(distance - 16.0) * 0.0001), 0.2);
        vec3 skyColor = isDay(worldTime) ? vec3(0.8, 0.9, 1.0) : vec3(0.2, 0.25, 0.4);
        finalColor = mix(finalColor, skyColor * 0.5, atmosphereFactor);
    }
    
    // Apply weather effects
    finalColor = applyRainDarkening(finalColor, rainStrength);
    
    color = vec4(finalColor, albedoColor.a);
    
    if (albedoColor.a < alphaTestRef) {
        discard;
    }
}