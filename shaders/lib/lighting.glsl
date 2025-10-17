// lighting.glsl - Advanced lighting functions for NeptuneShaders
// Include this file with: #include "lib/lighting.glsl"
// Requires: #include "lib/common.glsl"

#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL

// ============================================================================
// PBR MATERIAL STRUCTURE
// ============================================================================

struct Material {
    vec3 albedo;
    float metallic;
    float roughness;
    float reflectance;
    float subsurface;
    float emission;
};

// Create a default material
Material createDefaultMaterial(vec3 albedo) {
    Material mat;
    mat.albedo = albedo;
    mat.metallic = 0.0;
    mat.roughness = 0.8;
    mat.reflectance = 0.04;
    mat.subsurface = 0.0;
    mat.emission = 0.0;
    return mat;
}

// Create a metallic material
Material createMetallicMaterial(vec3 albedo, float roughness) {
    Material mat;
    mat.albedo = albedo;
    mat.metallic = 0.9;
    mat.roughness = roughness;
    mat.reflectance = 0.56;
    mat.subsurface = 0.0;
    mat.emission = 0.0;
    return mat;
}

// Create a foliage material
Material createFoliageMaterial(vec3 albedo) {
    Material mat;
    mat.albedo = albedo * GRASS_COLOR_ENHANCE;
    mat.metallic = 0.0;
    mat.roughness = 0.9;
    mat.reflectance = 0.02;
    mat.subsurface = 0.4;
    mat.emission = 0.0;
    return mat;
}

// ============================================================================
// LIGHTING MODELS
// ============================================================================

// Lambert diffuse
float lambertDiffuse(vec3 normal, vec3 lightDir) {
    return max(dot(normal, lightDir), 0.0);
}

// Phong specular
float phongSpecular(vec3 normal, vec3 lightDir, vec3 viewDir, float shininess) {
    vec3 reflectDir = reflect(-lightDir, normal);
    return pow(max(dot(viewDir, reflectDir), 0.0), shininess);
}

// Blinn-Phong specular  
float blinnPhongSpecular(vec3 normal, vec3 lightDir, vec3 viewDir, float shininess) {
    vec3 halfDir = normalize(lightDir + viewDir);
    return pow(max(dot(normal, halfDir), 0.0), shininess);
}

// Fresnel approximation (Schlick's approximation)
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// ============================================================================
// ADVANCED LIGHTING FUNCTIONS
// ============================================================================

// Calculate basic PBR lighting
vec3 calculatePBRLighting(Material mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor) {
    float NdotL = lambertDiffuse(normal, lightDir);
    float NdotV = max(dot(normal, viewDir), 0.0);
    
    // Base reflectance
    vec3 F0 = mix(vec3(mat.reflectance), mat.albedo, mat.metallic);
    
    // Fresnel
    vec3 F = fresnelSchlick(NdotV, F0);
    
    // Diffuse (energy conservation)
    vec3 kD = (1.0 - F) * (1.0 - mat.metallic);
    vec3 diffuse = kD * mat.albedo / PI;
    
    // Specular (simplified)
    float shininess = 1.0 / (mat.roughness * mat.roughness + 0.01);
    float specular = blinnPhongSpecular(normal, lightDir, viewDir, shininess);
    vec3 specularColor = F * specular;
    
    // Subsurface scattering approximation
    vec3 subsurface = vec3(0.0);
    if (mat.subsurface > 0.0) {
        float backLight = max(dot(-normal, lightDir), 0.0);
        subsurface = mat.albedo * lightColor * backLight * mat.subsurface * 0.5;
    }
    
    return (diffuse + specularColor) * lightColor * NdotL + subsurface + mat.albedo * mat.emission;
}

// Simplified lighting for performance
vec3 calculateSimpleLighting(vec3 albedo, vec3 normal, vec3 lightDir, vec3 lightColor, float roughness) {
    float NdotL = lambertDiffuse(normal, lightDir);
    
    // Simple ambient
    vec3 ambient = albedo * 0.1;
    
    // Diffuse
    vec3 diffuse = albedo * lightColor * NdotL;
    
    return ambient + diffuse;
}

// Calculate atmospheric lighting
vec3 calculateAtmosphericLighting(vec3 baseColor, vec3 viewDir, vec3 lightDir, float distance, int worldTime) {
    // Atmospheric perspective
    float atmosphereFactor = 1.0 - exp(-distance * 0.0001);
    atmosphereFactor = clamp(atmosphereFactor, 0.0, 0.3);
    
    // Sky color based on time
    vec3 skyColor;
    if (isDay(worldTime)) {
        skyColor = vec3(0.5, 0.7, 1.0);
    } else {
        skyColor = vec3(0.1, 0.15, 0.3);
    }
    
    return mix(baseColor, skyColor, atmosphereFactor);
}

// ============================================================================
// SHADOW FUNCTIONS
// ============================================================================

// Simple shadow mapping (placeholder)
float calculateShadow(vec3 worldPos, mat4 shadowMatrix, sampler2D shadowMap) {
    // This would be implemented with actual shadow mapping
    // For now, return no shadow
    return 1.0;
}

// Soft shadow approximation
float softShadow(vec3 worldPos, vec3 lightDir, float distance) {
    // Simple distance-based shadow softening
    return clamp(1.0 - distance * 0.001, 0.3, 1.0);
}

// ============================================================================
// SPECIAL EFFECTS
// ============================================================================

// Calculate rim lighting
vec3 calculateRimLighting(vec3 normal, vec3 viewDir, vec3 rimColor, float rimPower) {
    float rim = 1.0 - max(dot(normal, viewDir), 0.0);
    rim = pow(rim, rimPower);
    return rimColor * rim;
}

// Calculate emission glow
vec3 calculateEmission(vec3 baseColor, float emissionStrength, float time) {
    float pulse = sin(time * 4.0) * 0.1 + 0.9;
    return baseColor * emissionStrength * pulse;
}

// Calculate water caustics
vec3 calculateCaustics(vec3 worldPos, float time, float intensity) {
    vec2 causticsCoord = worldPos.xz * 0.1;
    float caustics = sin(causticsCoord.x * 8.0 + time) * cos(causticsCoord.y * 6.0 + time * 0.7);
    caustics += sin(causticsCoord.x * 12.0 + time * 1.3) * cos(causticsCoord.y * 10.0 + time * 0.9) * 0.5;
    caustics = max(caustics, 0.0) * intensity;
    return vec3(caustics * 0.3, caustics * 0.5, caustics * 0.8);
}

// ============================================================================
// UTILITY LIGHTING FUNCTIONS
// ============================================================================

// Enhance lightmap colors
vec3 enhanceLightmap(vec3 lightmapColor, float contrast) {
    return pow(lightmapColor, vec3(contrast));
}

// Apply distance fog
vec3 applyDistanceFog(vec3 color, float distance, vec3 fogColor, float fogDensity) {
    float fog = 1.0 - exp(-distance * fogDensity);
    return mix(color, fogColor, fog);
}

// Apply height fog
vec3 applyHeightFog(vec3 color, float height, vec3 fogColor, float fogHeight, float fogDensity) {
    float fog = exp(-(height - fogHeight) * fogDensity);
    fog = clamp(fog, 0.0, 1.0);
    return mix(fogColor, color, fog);
}

#endif // LIGHTING_GLSL