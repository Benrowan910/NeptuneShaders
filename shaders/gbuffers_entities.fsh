#version 330 compatibility

// Uniforms
uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform vec4 entityColor;
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
flat in int entityId;

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Material properties for entities
struct EntityMaterial {
    float metallic;
    float roughness;
    float reflectance;
    float subsurface;
    float emission;
    vec3 albedo;
};

// Entity material classification
EntityMaterial getEntityMaterial(vec4 albedoColor, int entityId) {
    EntityMaterial mat;
    
    // Default organic material (skin, fur, etc.)
    mat.metallic = 0.0;
    mat.roughness = 0.7;
    mat.reflectance = 0.04;
    mat.subsurface = 0.2; // Most entities have some subsurface scattering
    mat.emission = 0.0;
    mat.albedo = albedoColor.rgb;
    
    vec3 color = albedoColor.rgb;
    float brightness = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Metallic entities (Iron Golems, etc.)
    if ((color.r > 0.4 && color.r < 0.8) && 
        (color.g > 0.4 && color.g < 0.8) && 
        (color.b > 0.4 && color.b < 0.8) && 
        abs(color.r - color.g) < 0.2 && brightness > 0.5) {
        mat.metallic = 0.8;
        mat.roughness = 0.3;
        mat.reflectance = 0.56;
        mat.subsurface = 0.0;
    }
    
    // Wet entities (water-based mobs)
    else if (color.b > 0.6 && color.b > color.r && color.b > color.g) {
        mat.roughness = 0.1;
        mat.reflectance = 0.08;
        mat.subsurface = 0.1;
    }
    
    // Glowing entities (Blaze, Glowstone entities, etc.)
    else if (brightness > 0.8 && (color.r > 0.7 || color.g > 0.7)) {
        mat.emission = 0.5;
        mat.roughness = 0.2;
        mat.subsurface = 0.0;
    }
    
    // Dark entities (Endermen, shadows, etc.)
    else if (brightness < 0.3) {
        mat.roughness = 0.9;
        mat.reflectance = 0.02;
        mat.subsurface = 0.05;
    }
    
    // Shiny entities (Slimes, etc.)
    else if (color.g > 0.6 && brightness > 0.5) {
        mat.roughness = 0.2;
        mat.reflectance = 0.1;
        mat.subsurface = 0.3;
    }
    
    // Armored entities
    else if (brightness > 0.6 && abs(color.r - color.g) < 0.3 && abs(color.g - color.b) < 0.3) {
        mat.metallic = 0.6;
        mat.roughness = 0.4;
        mat.reflectance = 0.5;
        mat.subsurface = 0.0;
    }
    
    return mat;
}

// Fresnel calculation
float fresnel(vec3 viewDir, vec3 normal, float f0) {
    float cosTheta = max(0.0, dot(-viewDir, normal));
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

// Enhanced Blinn-Phong for entities
float blinnPhong(vec3 lightDir, vec3 viewDir, vec3 normal, float shininess) {
    vec3 halfVector = normalize(lightDir - viewDir);
    float NdotH = max(0.0, dot(normal, halfVector));
    float normalizationFactor = (shininess + 8.0) / (8.0 * 3.14159);
    return pow(NdotH, shininess) * normalizationFactor;
}

// Subsurface scattering for organic entities
vec3 calculateSubsurface(vec3 lightDir, vec3 normal, vec3 albedo, float subsurface) {
    if (subsurface < 0.01) return vec3(0.0);
    
    // Enhanced subsurface for entities (skin, fur, etc.)
    float backLight = max(0.0, dot(-lightDir, normal));
    float sideLight = max(0.0, dot(lightDir, normalize(cross(normal, vec3(0.0, 1.0, 0.0)))));
    
    vec3 subsurfaceColor = albedo * (backLight * 0.7 + sideLight * 0.3) * subsurface;
    return subsurfaceColor;
}

// Environment reflection for entities
vec3 getEntityReflection(vec3 normal, vec3 viewDir, float roughness) {
    vec3 reflectDir = reflect(viewDir, normal);
    
    float skyFactor = max(0.0, reflectDir.y);
    vec3 envColor = mix(fogColor, skyColor, skyFactor);
    
    // Entities move, so add some dynamic variation
    float dynamicFactor = sin(frameTimeCounter * 2.0 + float(entityId)) * 0.1 + 0.9;
    
    return envColor * dynamicFactor * (1.0 - roughness * 0.7);
}

// PBR lighting for entities
vec3 calculateEntityLighting(EntityMaterial mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor) {
    float NdotL = max(0.0, dot(normal, lightDir));
    
    // Diffuse with Lambert
    vec3 diffuse = mat.albedo * NdotL / 3.14159;
    
    // Enhanced subsurface scattering for organic entities
    vec3 subsurface = calculateSubsurface(lightDir, normal, mat.albedo, mat.subsurface);
    
    // Metallic workflow
    vec3 f0 = mix(vec3(mat.reflectance), mat.albedo, mat.metallic);
    
    // Fresnel
    float fresnelFactor = fresnel(viewDir, normal, mat.reflectance);
    
    // Specular
    float shininess = (1.0 - mat.roughness) * 128.0 + 1.0;
    float specular = blinnPhong(lightDir, viewDir, normal, shininess);
    
    // Environment reflection (more subtle for entities)
    vec3 envReflection = vec3(0.0);
    if (mat.metallic > 0.1 || mat.reflectance > 0.05) {
        envReflection = getEntityReflection(normal, viewDir, mat.roughness) * 
                       mix(fresnelFactor, mat.metallic, mat.metallic) * 0.2;
    }
    
    // Emission for glowing entities
    vec3 emission = mat.albedo * mat.emission;
    
    // Combine lighting
    vec3 result = diffuse * (1.0 - mat.metallic) * lightColor;
    result += subsurface * lightColor * 0.8;
    result += specular * f0 * lightColor * NdotL;
    result += envReflection;
    result += emission;
    
    // Ambient lighting (more important for entities)
    result += mat.albedo * 0.05 * (1.0 - mat.metallic);
    
    return result;
}

void main() {
    // Get base color and apply entity color overlay
    vec4 albedoColor = texture(gtexture, texcoord) * glcolor;
    albedoColor.rgb = mix(albedoColor.rgb, entityColor.rgb, entityColor.a);
    
    // Get entity material properties
    EntityMaterial mat = getEntityMaterial(albedoColor, entityId);
    
    // Normalize normal and calculate view direction
    vec3 surfaceNormal = normalize(normal);
    vec3 viewDir = normalize(viewPos);
    
    // Light setup
    bool isDay = worldTime > 1000 && worldTime < 13000;
    vec3 lightPos = isDay ? sunPosition : moonPosition;
    vec3 lightDir = normalize(lightPos);
    
    // Light color with time variation
    vec3 lightColor;
    if (isDay) {
        float dayProgress = (float(worldTime) - 1000.0) / 12000.0;
        float sunHeight = sin(dayProgress * 3.14159);
        lightColor = mix(vec3(1.0, 0.7, 0.4), vec3(1.0, 1.0, 0.98), sunHeight);
    } else {
        lightColor = vec3(0.25, 0.3, 0.45);
    }
    
    // Calculate entity lighting
    vec3 finalColor = calculateEntityLighting(mat, surfaceNormal, viewDir, lightDir, lightColor);
    
    // Apply lightmap with entity-specific adjustments
    vec3 lightmapColor = texture(lightmap, lmcoord).rgb;
    
    // Entities often need more contrast in lighting
    lightmapColor = pow(lightmapColor, vec3(0.75));
    finalColor *= lightmapColor;
    
    // Add subtle animation effects for living entities
    if (mat.subsurface > 0.1) {
        float pulse = sin(frameTimeCounter * 4.0 + float(entityId) * 10.0) * 0.02 + 1.0;
        finalColor *= pulse;
    }
    
    color = vec4(finalColor, albedoColor.a);
    
    if (color.a < alphaTestRef) {
        discard;
    }
}