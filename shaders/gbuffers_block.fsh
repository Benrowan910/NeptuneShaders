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

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    // Get base color
    vec4 albedoColor = texture(gtexture, texcoord) * glcolor;
    
    // Create material based on color analysis
    Material mat = createDefaultMaterial(albedoColor.rgb);
    
    // Enhanced material detection for blocks
    if (isMetallic(albedoColor.rgb)) {
        mat = createMetallicMaterial(albedoColor.rgb, 0.2);
    } else if (isGold(albedoColor.rgb)) {
        mat = createMetallicMaterial(GOLD_COLOR, 0.1);
        mat.reflectance = 0.47;
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
    
    // Apply atmospheric effects
    float distance = length(viewPos);
    finalColor = calculateAtmosphericLighting(finalColor, viewDir, lightDir, distance, worldTime);
    
    // Apply weather effects
    finalColor = applyRainDarkening(finalColor, rainStrength);
    
    // Output final color
    color = vec4(finalColor, albedoColor.a);
    
    if (color.a < alphaTestRef) {
        discard;
    }
}

// Material properties structure
struct MaterialProperties {
    float metallic;
    float roughness;
    float reflectance;
    vec3 albedo;
};

// Detect material properties based on texture and block ID
MaterialProperties getMaterialProperties(vec4 albedoColor, float blockId) {
    MaterialProperties mat;
    
    // Default non-metallic properties
    mat.metallic = 0.0;
    mat.roughness = 0.8;
    mat.reflectance = 0.04;
    mat.albedo = albedoColor.rgb;
    
    // Detect metallic materials based on color analysis and block ID
    vec3 color = albedoColor.rgb;
    float brightness = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Iron blocks (typically dark gray with metallic sheen)
    if ((color.r > 0.3 && color.r < 0.7) && 
        (color.g > 0.3 && color.g < 0.7) && 
        (color.b > 0.3 && color.b < 0.7) && 
        abs(color.r - color.g) < 0.1 && abs(color.g - color.b) < 0.1 &&
        brightness > 0.4) {
        mat.metallic = 0.8;
        mat.roughness = 0.2;
        mat.reflectance = 0.56; // Iron reflectance
    }
    
    // Gold blocks (yellow/golden color)
    else if (color.r > 0.6 && color.g > 0.5 && color.b < 0.4 &&
             color.r > color.g && color.g > color.b) {
        mat.metallic = 0.9;
        mat.roughness = 0.1;
        mat.reflectance = 0.47; // Gold reflectance
        mat.albedo = vec3(1.0, 0.86, 0.57); // Enhance gold color
    }
    
    // Copper blocks (orange/brown metallic)
    else if (color.r > 0.5 && color.g > 0.3 && color.g < 0.6 && color.b < 0.4 &&
             color.r > color.g && color.g > color.b) {
        mat.metallic = 0.7;
        mat.roughness = 0.3;
        mat.reflectance = 0.95; // Copper reflectance
        mat.albedo = vec3(0.95, 0.64, 0.54); // Enhance copper color
    }
    
    // Diamond blocks (high reflectance, not metallic but very shiny)
    else if (brightness > 0.8 && 
             abs(color.r - color.g) < 0.1 && abs(color.g - color.b) < 0.1) {
        mat.metallic = 0.0;
        mat.roughness = 0.05;
        mat.reflectance = 0.17; // Diamond-like reflectance
    }
    
    // Netherite (dark with purple tint)
    else if (brightness < 0.3 && color.b > color.r && color.b > color.g) {
        mat.metallic = 0.8;
        mat.roughness = 0.4;
        mat.reflectance = 0.6;
        mat.albedo = vec3(0.3, 0.2, 0.4); // Enhance netherite color
    }
    
    return mat;
}

// Fresnel calculation for reflections
float fresnel(vec3 viewDir, vec3 normal, float f0) {
    float cosTheta = max(0.0, dot(-viewDir, normal));
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

// Blinn-Phong specular calculation
float blinnPhong(vec3 lightDir, vec3 viewDir, vec3 normal, float shininess) {
    vec3 halfVector = normalize(lightDir - viewDir);
    float NdotH = max(0.0, dot(normal, halfVector));
    return pow(NdotH, shininess);
}

// Simple environment reflection
vec3 getEnvironmentReflection(vec3 normal, vec3 viewDir) {
    vec3 reflectDir = reflect(viewDir, normal);
    
    // Simple sky/environment reflection
    float skyFactor = max(0.0, reflectDir.y);
    vec3 envColor = mix(fogColor * 0.8, skyColor, skyFactor);
    
    // Add some variation based on time and position
    float timeVariation = sin(frameTimeCounter * 0.3 + worldPos.x * 0.1) * 0.1 + 0.9;
    return envColor * timeVariation;
}

// PBR-style lighting calculation
vec3 calculatePBRLighting(MaterialProperties mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor) {
    // Lambertian diffuse
    float NdotL = max(0.0, dot(normal, lightDir));
    vec3 diffuse = mat.albedo * NdotL;
    
    // Metallic workflow: lerp between dielectric and metallic
    vec3 f0 = mix(vec3(mat.reflectance), mat.albedo, mat.metallic);
    
    // Fresnel for reflections
    float fresnelFactor = fresnel(viewDir, normal, mat.reflectance);
    
    // Specular (Blinn-Phong approximation of PBR)
    float shininess = (1.0 - mat.roughness) * 256.0 + 1.0;
    float specular = blinnPhong(lightDir, viewDir, normal, shininess);
    
    // Environment reflection for metallic materials
    vec3 envReflection = vec3(0.0);
    if (mat.metallic > 0.1) {
        envReflection = getEnvironmentReflection(normal, viewDir) * mat.metallic * fresnelFactor;
    }
    
    // Combine lighting
    vec3 result = diffuse * (1.0 - mat.metallic) * lightColor;
    result += specular * f0 * lightColor;
    result += envReflection * (1.0 - mat.roughness);
    
    return result;
}

