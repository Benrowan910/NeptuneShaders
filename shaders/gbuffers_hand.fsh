#version 330 compatibility

// Uniforms
uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float frameTimeCounter;
uniform float alphaTestRef = 0.1;

// Inputs from vertex shader
in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPos;
in vec3 viewPos;
in vec3 normal;
in float itemId;

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Material properties for hand items
struct ItemMaterial {
    float metallic;
    float roughness;
    float reflectance;
    float emission;
    vec3 albedo;
};

// Item material classification (tools, weapons, etc.)
ItemMaterial getItemMaterial(vec4 albedoColor, float itemId) {
    ItemMaterial mat;
    
    // Default material
    mat.metallic = 0.0;
    mat.roughness = 0.6;
    mat.reflectance = 0.04;
    mat.emission = 0.0;
    mat.albedo = albedoColor.rgb;
    
    vec3 color = albedoColor.rgb;
    float brightness = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Metal tools and weapons (swords, pickaxes, armor)
    if ((brightness > 0.5 && brightness < 0.9) &&
        abs(color.r - color.g) < 0.2 && abs(color.g - color.b) < 0.2) {
        
        // Iron tools
        if (brightness < 0.7) {
            mat.metallic = 0.8;
            mat.roughness = 0.2;
            mat.reflectance = 0.56;
            mat.albedo = vec3(0.7, 0.7, 0.75);
        }
        // Steel/Diamond tools (brighter)
        else {
            mat.metallic = 0.9;
            mat.roughness = 0.1;
            mat.reflectance = 0.7;
            mat.albedo = vec3(0.9, 0.9, 0.95);
        }
    }
    
    // Gold tools and items
    else if (color.r > 0.6 && color.g > 0.5 && color.b < 0.4 &&
             color.r > color.g && color.g > color.b) {
        mat.metallic = 0.95;
        mat.roughness = 0.05;
        mat.reflectance = 0.47;
        mat.albedo = vec3(1.0, 0.86, 0.57);
    }
    
    // Copper tools
    else if (color.r > 0.5 && color.g > 0.3 && color.g < 0.6 && color.b < 0.4) {
        mat.metallic = 0.7;
        mat.roughness = 0.25;
        mat.reflectance = 0.95;
        mat.albedo = vec3(0.95, 0.64, 0.54);
    }
    
    // Netherite tools (dark with purple tint)
    else if (brightness < 0.4 && color.b > color.r) {
        mat.metallic = 0.85;
        mat.roughness = 0.3;
        mat.reflectance = 0.6;
        mat.albedo = vec3(0.3, 0.2, 0.4);
    }
    
    // Glowing items (enchanted items, torches, etc.)
    else if (brightness > 0.8 && (color.r > 0.8 || color.g > 0.8)) {
        mat.emission = 0.3;
        mat.roughness = 0.1;
        mat.albedo = color * 1.2; // Enhance brightness
    }
    
    // Wood items (handles, tools)
    else if (color.r > 0.3 && color.g > 0.2 && color.b < 0.3 &&
             color.r > color.b && color.g > color.b) {
        mat.roughness = 0.8;
        mat.reflectance = 0.02;
        mat.albedo = color * 1.1;
    }
    
    // Leather items
    else if (brightness > 0.2 && brightness < 0.6 &&
             color.r > color.b && color.g > color.b) {
        mat.roughness = 0.9;
        mat.reflectance = 0.01;
    }
    
    // Glass items
    else if (brightness > 0.7 && abs(color.r - color.g) < 0.2 && abs(color.g - color.b) < 0.2) {
        mat.metallic = 0.0;
        mat.roughness = 0.05;
        mat.reflectance = 0.08;
    }
    
    return mat;
}

// Fresnel calculation
float fresnel(vec3 viewDir, vec3 normal, float f0) {
    float cosTheta = max(0.0, dot(-viewDir, normal));
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

// Enhanced Blinn-Phong for items
float blinnPhong(vec3 lightDir, vec3 viewDir, vec3 normal, float shininess) {
    vec3 halfVector = normalize(lightDir - viewDir);
    float NdotH = max(0.0, dot(normal, halfVector));
    float normalizationFactor = (shininess + 8.0) / (8.0 * 3.14159);
    return pow(NdotH, shininess) * normalizationFactor;
}

// Enhanced environment reflection for hand items
vec3 getItemReflection(vec3 normal, vec3 viewDir, float roughness) {
    vec3 reflectDir = reflect(viewDir, normal);
    
    float skyFactor = max(0.0, reflectDir.y);
    vec3 envColor = mix(fogColor, skyColor, skyFactor);
    
    // Hand items are close to camera, so reflections should be more prominent
    float proximityBoost = 1.2;
    
    return envColor * proximityBoost * (1.0 - roughness * 0.6);
}

// PBR lighting for hand items
vec3 calculateItemLighting(ItemMaterial mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor) {
    float NdotL = max(0.0, dot(normal, lightDir));
    
    // Diffuse
    vec3 diffuse = mat.albedo * NdotL / 3.14159;
    
    // Metallic workflow
    vec3 f0 = mix(vec3(mat.reflectance), mat.albedo, mat.metallic);
    
    // Fresnel
    float fresnelFactor = fresnel(viewDir, normal, mat.reflectance);
    
    // Specular (enhanced for items to show detail)
    float shininess = (1.0 - mat.roughness) * 256.0 + 16.0;
    float specular = blinnPhong(lightDir, viewDir, normal, shininess);
    
    // Environment reflection (more prominent for hand items)
    vec3 envReflection = vec3(0.0);
    if (mat.metallic > 0.1 || mat.reflectance > 0.05) {
        envReflection = getItemReflection(normal, viewDir, mat.roughness) * 
                       mix(fresnelFactor, mat.metallic, mat.metallic) * 0.6;
    }
    
    // Emission for glowing items
    vec3 emission = mat.albedo * mat.emission;
    
    // Combine lighting
    vec3 result = diffuse * (1.0 - mat.metallic) * lightColor;
    result += specular * f0 * lightColor * NdotL * 1.5; // Enhanced specular for items
    result += envReflection;
    result += emission;
    
    // Enhanced ambient for hand items (they should be clearly visible)
    result += mat.albedo * 0.08 * (1.0 - mat.metallic);
    
    return result;
}

void main() {
    // Get base color
    vec4 albedoColor = texture(gtexture, texcoord) * glcolor;
    
    // Get item material properties
    ItemMaterial mat = getItemMaterial(albedoColor, itemId);
    
    // Normalize normal and calculate view direction
    vec3 surfaceNormal = normalize(normal);
    vec3 viewDir = normalize(viewPos);
    
    // Light setup
    bool isDay = worldTime > 1000 && worldTime < 13000;
    vec3 lightPos = isDay ? sunPosition : moonPosition;
    vec3 lightDir = normalize(lightPos);
    
    // Enhanced light color for items
    vec3 lightColor;
    if (isDay) {
        float dayProgress = (float(worldTime) - 1000.0) / 12000.0;
        float sunHeight = sin(dayProgress * 3.14159);
        lightColor = mix(vec3(1.0, 0.8, 0.5), vec3(1.0, 1.0, 0.98), sunHeight);
        lightColor *= 1.1; // Boost for hand items
    } else {
        lightColor = vec3(0.3, 0.35, 0.5);
    }
    
    // Calculate item lighting
    vec3 finalColor = calculateItemLighting(mat, surfaceNormal, viewDir, lightDir, lightColor);
    
    // Apply lightmap with hand-specific adjustments
    vec3 lightmapColor = texture(lightmap, lmcoord).rgb;
    
    // Hand items should have more contrast and brightness
    lightmapColor = pow(lightmapColor, vec3(0.7));
    lightmapColor *= 1.2; // Brightness boost
    finalColor *= lightmapColor;
    
    // Subtle animation for enchanted items
    if (mat.emission > 0.1) {
        float enchantGlow = sin(frameTimeCounter * 6.0) * 0.05 + 1.0;
        finalColor *= enchantGlow;
    }
    
    color = vec4(finalColor, albedoColor.a);
    
    if (color.a < alphaTestRef) {
        discard;
    }
}