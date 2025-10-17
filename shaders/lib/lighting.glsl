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
// SHADOW FUNCTIONS
// ============================================================================

// Calculate simple directional shadows based on normal and light direction
float calculateDirectionalShadow(vec3 normal, vec3 lightDir, vec2 lightmapCoord) {
    // Use the lightmap's red channel which often contains shadow information
    float shadowFactor = clamp(lightmapCoord.x, 0.0, 1.0); // Clamp to prevent artifacts
    
    // Enhance shadow based on surface normal relative to light
    float NdotL = max(dot(normal, lightDir), 0.0); // Ensure positive values
    float shadowMod = smoothstep(0.0, 0.5, NdotL);
    
    // Stronger shadow contrast - don't multiply, use minimum
    return mix(0.1, 1.0, min(shadowFactor, shadowMod));
}

// Calculate ambient occlusion from lightmap
float calculateAmbientOcclusion(vec2 lightmapCoord) {
    // Lightmap's second channel often contains ambient occlusion info
    float ao = lightmapCoord.y;
    // Reduce corner darkness by making AO less aggressive
    return mix(0.4, 1.0, ao); // Changed from 0.2 to 0.4 for less dark corners
}

// Calculate dynamic shadow factor based on time of day and position
float calculateDynamicShadow(vec3 worldPos, vec3 lightDir, int worldTime) {
    // Remove height-based shadow reduction that was washing out above-ground shadows
    // Simple time-based shadow intensity only
    float timeOfDay = float(worldTime) / 24000.0;
    float shadowIntensity;
    
    if (isDay(worldTime)) {
        // Much stronger shadows during day
        shadowIntensity = sin(timeOfDay * PI) * 0.6 + 0.4; // 0.4 to 1.0 range
    } else {
        // Still visible shadows at night
        shadowIntensity = 0.3;
    }
    
    return shadowIntensity;
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

// Calculate basic PBR lighting with shadows (atmospheric version)
vec3 calculatePBRLighting(Material mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor, vec2 lightmapCoord, vec3 worldPos, int worldTime) {
    float NdotL = lambertDiffuse(normal, lightDir);
    float NdotV = max(dot(normal, viewDir), 0.0);
    
    // Clamp lightmap coordinates to prevent artifacts
    vec2 safeLightmapCoord = clamp(lightmapCoord, 0.0, 1.0);
    
    // Calculate shadows using clamped lightmap values
    float directionalShadow = calculateDirectionalShadow(normal, lightDir, safeLightmapCoord);
    float ambientOcclusion = calculateAmbientOcclusion(safeLightmapCoord);
    float dynamicShadow = calculateDynamicShadow(worldPos, lightDir, worldTime);
    
    // Fix shadow combination - use additive instead of multiplicative
    float shadowFactor = clamp(min(directionalShadow + dynamicShadow * 0.5, 1.0), 0.0, 1.0);
    
    // Base reflectance
    vec3 F0 = mix(vec3(mat.reflectance), mat.albedo, mat.metallic);
    
    // Softer Fresnel for atmospheric feel
    vec3 F = fresnelSchlick(NdotV, F0);
    F = mix(F0, F, 0.7); // Reduce Fresnel intensity
    
    // Diffuse (energy conservation)
    vec3 kD = (1.0 - F) * (1.0 - mat.metallic);
    vec3 diffuse = kD * mat.albedo / PI;
    
    // Softer specular for atmospheric lighting
    float shininess = 1.0 / (mat.roughness * mat.roughness + 0.01);
    shininess = min(shininess, 32.0); // Limit shininess for softer look
    float specular = blinnPhongSpecular(normal, lightDir, viewDir, shininess);
    vec3 specularColor = F * specular * 0.3; // Reduced specular intensity
    
    // Apply lightmap-based ambient with AO but ensure minimum lighting
    float lightmapInfluence = max(safeLightmapCoord.y, 0.2); // Minimum ambient to prevent total darkness
    vec3 ambient = mat.albedo * 0.08 * ambientOcclusion * lightmapInfluence;
    
    // Subsurface scattering approximation (softer)
    vec3 subsurface = vec3(0.0);
    if (mat.subsurface > 0.0) {
        float backLight = max(dot(-normal, lightDir), 0.0);
        subsurface = mat.albedo * lightColor * backLight * mat.subsurface * 0.3 * shadowFactor;
    }
    
    // Combine with atmospheric weighting and shadows, incorporating lightmap influence
    vec3 directLighting = (diffuse + specularColor) * lightColor * NdotL * shadowFactor * safeLightmapCoord.x;
    
    return ambient + directLighting + subsurface + mat.albedo * mat.emission;
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

// Calculate atmospheric lighting (enhanced spatial version)
vec3 calculateAtmosphericLighting(vec3 baseColor, vec3 viewDir, vec3 lightDir, float distance, int worldTime) {
    // Enhanced atmospheric perspective with spatial depth
    float atmosphereFactor = 1.0 - exp(-distance * 0.00008); // More gradual falloff
    atmosphereFactor = clamp(atmosphereFactor, 0.0, 0.4);
    
    // Sky color based on time with more atmospheric variation
    vec3 skyColor;
    if (isDay(worldTime)) {
        if (isSunrise(worldTime) || isSunset(worldTime)) {
            skyColor = vec3(0.8, 0.6, 0.4); // Warm atmospheric haze
        } else {
            skyColor = vec3(0.6, 0.75, 1.0); // Atmospheric blue
        }
    } else {
        skyColor = vec3(0.15, 0.2, 0.35); // Atmospheric night haze
    }
    
    // Add subtle directional atmospheric scattering
    float lightAlignment = dot(viewDir, lightDir);
    float scattering = pow(max(lightAlignment, 0.0), 4.0) * 0.1;
    skyColor += vec3(scattering * 0.5, scattering * 0.3, scattering * 0.1);
    
    // Distance-based atmospheric mixing
    return mix(baseColor, skyColor, atmosphereFactor);
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