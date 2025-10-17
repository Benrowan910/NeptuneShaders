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
in float blockId;
in float foliageType;

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Material properties structure
struct MaterialProperties {
    float metallic;
    float roughness;
    float reflectance;
    float subsurface;
    vec3 albedo;
};

// Enhanced material detection including foliage
MaterialProperties getMaterialProperties(vec4 albedoColor, float blockId, float foliageType) {
    MaterialProperties mat;
    
    // Default non-metallic properties
    mat.metallic = 0.0;
    mat.roughness = 0.8;
    mat.reflectance = 0.04;
    mat.subsurface = 0.0;
    mat.albedo = albedoColor.rgb;
    
    // Detect metallic materials based on color analysis
    vec3 color = albedoColor.rgb;
    float brightness = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Foliage materials
    if (foliageType > 0.1) {
        mat.roughness = 0.9;
        mat.reflectance = 0.02;
        mat.subsurface = 0.4; // Leaves have strong subsurface scattering
        
        // Enhance foliage colors
        if (foliageType > 0.8) {
            // Tree leaves - enhance green and add slight variation
            mat.albedo = color * vec3(0.9, 1.15, 0.9);
        } else {
            // Grass - slightly different enhancement
            mat.albedo = color * vec3(0.95, 1.1, 0.95);
        }
    }
    
    // Iron/Metal ores and blocks (typically dark gray with metallic sheen)
    if ((color.r > 0.3 && color.r < 0.7) && 
        (color.g > 0.3 && color.g < 0.7) && 
        (color.b > 0.3 && color.b < 0.7) && 
        abs(color.r - color.g) < 0.1 && abs(color.g - color.b) < 0.1 &&
        brightness > 0.4) {
        mat.metallic = 0.8;
        mat.roughness = 0.3;
        mat.reflectance = 0.56;
    }
    
    // Gold ores and blocks (yellow/golden color)
    else if (color.r > 0.6 && color.g > 0.5 && color.b < 0.4 &&
             color.r > color.g && color.g > color.b) {
        mat.metallic = 0.9;
        mat.roughness = 0.1;
        mat.reflectance = 0.47;
        mat.albedo = vec3(1.0, 0.86, 0.57);
    }
    
    // Copper ores and blocks (orange/brown metallic)
    else if (color.r > 0.5 && color.g > 0.3 && color.g < 0.6 && color.b < 0.4 &&
             color.r > color.g && color.g > color.b) {
        mat.metallic = 0.7;
        mat.roughness = 0.3;
        mat.reflectance = 0.95;
        mat.albedo = vec3(0.95, 0.64, 0.54);
    }
    
    // Diamond ores and blocks (high reflectance)
    else if (brightness > 0.8 && 
             abs(color.r - color.g) < 0.1 && abs(color.g - color.b) < 0.1) {
        mat.metallic = 0.0;
        mat.roughness = 0.05;
        mat.reflectance = 0.17;
    }
    
    // Water-like blocks (ice, etc.)
    else if (color.b > 0.7 && color.b > color.r && color.b > color.g) {
        mat.metallic = 0.0;
        mat.roughness = 0.1;
        mat.reflectance = 0.08;
    }
    
    // Stone-like materials
    else if (brightness < 0.5 && abs(color.r - color.g) < 0.2 && abs(color.g - color.b) < 0.2) {
        mat.roughness = 0.9;
        mat.reflectance = 0.02;
    }
    
    return mat;
}

// Enhanced subsurface scattering calculation
vec3 calculateSubsurface(vec3 lightDir, vec3 normal, vec3 albedo, float subsurface) {
    if (subsurface < 0.01) return vec3(0.0);
    
    // Back-lighting effect for subsurface scattering
    float backLight = max(0.0, dot(-lightDir, normal));
    float sideLight = max(0.0, dot(lightDir, normalize(cross(normal, vec3(0.0, 1.0, 0.0)))));
    
    // Combine back and side lighting
    vec3 subsurfaceColor = albedo * (backLight * 0.8 + sideLight * 0.2) * subsurface;
    
    return subsurfaceColor;
}
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
vec3 calculatePBRLighting(MaterialProperties mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor, float foliageType) {
    // Lambertian diffuse
    float NdotL = max(0.0, dot(normal, lightDir));
    vec3 diffuse = mat.albedo * NdotL;
    
    // Subsurface scattering for foliage
    vec3 subsurface = calculateSubsurface(lightDir, normal, mat.albedo, mat.subsurface);
    
    // Metallic workflow: lerp between dielectric and metallic
    vec3 f0 = mix(vec3(mat.reflectance), mat.albedo, mat.metallic);
    
    // Fresnel for reflections
    float fresnelFactor = fresnel(viewDir, normal, mat.reflectance);
    
    // Specular (Blinn-Phong approximation of PBR)
    float shininess = (1.0 - mat.roughness) * 256.0 + 1.0;
    float specular = blinnPhong(lightDir, viewDir, normal, shininess);
    
    // Environment reflection for metallic/shiny materials
    vec3 envReflection = vec3(0.0);
    if (mat.metallic > 0.1 || mat.reflectance > 0.1) {
        envReflection = getEnvironmentReflection(normal, viewDir) * 
                       mix(fresnelFactor, mat.metallic, mat.metallic) * 
                       (1.0 - mat.roughness);
    }
    
    // Combine lighting
    vec3 result = diffuse * (1.0 - mat.metallic) * lightColor;
    result += subsurface * lightColor; // Add subsurface scattering
    result += specular * f0 * lightColor;
    result += envReflection * 0.5;
    
    // Enhanced ambient for foliage
    if (foliageType > 0.1) {
        result += mat.albedo * 0.05 * (1.0 - mat.metallic);
        
        // Add wind-based lighting flicker for leaves
        float windFlicker = sin(frameTimeCounter * 8.0 + worldPos.x + worldPos.z) * 0.03 + 1.0;
        result *= windFlicker;
    }
    
    return result;
}

void main() {
    // Get base color
    vec4 albedoColor = texture(gtexture, texcoord) * glcolor;
    
    // Simple material properties for Iris compatibility
    vec3 baseColor = albedoColor.rgb;
    
    // Basic lighting (reduced brightness)
    vec3 lightmapColor = texture(lightmap, lmcoord).rgb;
    lightmapColor *= 0.8; // Reduce brightness
    
    // Simple final color calculation
    vec3 finalColor = baseColor * lightmapColor;
    
    // Add slight green enhancement for foliage (no animation)
    if (foliageType > 0.5) {
        finalColor *= vec3(0.95, 1.05, 0.95);
    }
    
    // Reduce overall brightness to fix "super bright" issue
    finalColor *= 0.9;
    
    color = vec4(finalColor, albedoColor.a);
    
    if (albedoColor.a < alphaTestRef) {
        discard;
    }
}