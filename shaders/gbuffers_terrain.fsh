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
    // Get base color
    vec4 albedoColor = texture(gtexture, texcoord) * glcolor;
    
    // Create material based on properties
    Material mat = createDefaultMaterial(albedoColor.rgb);
    
    // Enhanced foliage materials
    if (foliageType > 0.5) {
        mat = createFoliageMaterial(albedoColor.rgb);
    }
    
    // Basic metallic detection for terrain blocks
    if (isMetallic(albedoColor.rgb)) {
        mat = createMetallicMaterial(albedoColor.rgb, 0.3);
    }
    
    // Setup lighting
    vec3 surfaceNormal = normalize(normal);
    vec3 viewDir = normalize(-viewPos);
    vec3 lightDir = getLightDirection(sunPosition, moonPosition, worldTime);
    vec3 lightColor = getLightColor(worldTime, rainStrength);
    
    // Calculate atmospheric PBR lighting
    vec3 finalColor = calculatePBRLighting(mat, surfaceNormal, viewDir, lightDir, lightColor);
    
    // Apply lightmap (natural intensity)
    vec3 lightmapColor = texture(lightmap, lmcoord).rgb;
    finalColor *= lightmapColor;
    
    // Apply atmospheric effects based on distance
    float distance = length(viewPos);
    finalColor = calculateAtmosphericLighting(finalColor, viewDir, lightDir, distance, worldTime);
    
    // Apply weather effects
    finalColor = applyRainDarkening(finalColor, rainStrength);
    
    color = vec4(finalColor, albedoColor.a);
    
    if (albedoColor.a < alphaTestRef) {
        discard;
    }
}