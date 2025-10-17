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
in float windEffect;

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

// Enhanced material detection for textured objects
MaterialProperties getMaterialProperties(vec4 albedoColor, float blockId, float windEffect) {
    MaterialProperties mat;
    
    // Default properties
    mat.metallic = 0.0;
    mat.roughness = 0.7;
    mat.reflectance = 0.04;
    mat.subsurface = 0.0;
    mat.albedo = albedoColor.rgb;
    
    vec3 color = albedoColor.rgb;
    float brightness = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Foliage materials (if wind effect is applied)
    if (windEffect > 0.5) {
        mat.roughness = 0.8;
        mat.reflectance = 0.02;
        mat.subsurface = 0.3; // Leaves have subsurface scattering
        
        // Enhance green tones for leaves
        if (color.g > color.r && color.g > color.b) {
            mat.albedo = color * vec3(0.9, 1.1, 0.9);
        }
    }
    
    // Metallic materials detection
    // Iron/Steel (gray metallic)
    else if ((color.r > 0.3 && color.r < 0.7) && 
        (color.g > 0.3 && color.g < 0.7) && 
        (color.b > 0.3 && color.b < 0.7) && 
        abs(color.r - color.g) < 0.1 && abs(color.g - color.b) < 0.1 &&
        brightness > 0.4) {
        mat.metallic = 0.8;
        mat.roughness = 0.3;
        mat.reflectance = 0.56;
    }
    
    // Gold materials
    else if (color.r > 0.6 && color.g > 0.5 && color.b < 0.4 &&
             color.r > color.g && color.g > color.b) {
        mat.metallic = 0.9;
        mat.roughness = 0.1;
        mat.reflectance = 0.47;
        mat.albedo = vec3(1.0, 0.86, 0.57);
    }
    
    // Copper materials
    else if (color.r > 0.5 && color.g > 0.3 && color.g < 0.6 && color.b < 0.4 &&
             color.r > color.g && color.g > color.b) {
        mat.metallic = 0.7;
        mat.roughness = 0.3;
        mat.reflectance = 0.95;
        mat.albedo = vec3(0.95, 0.64, 0.54);
    }
    
    // Glass-like materials (high brightness, even color distribution)
    else if (brightness > 0.7 && 
             abs(color.r - color.g) < 0.15 && abs(color.g - color.b) < 0.15) {
        mat.metallic = 0.0;
        mat.roughness = 0.05;
        mat.reflectance = 0.08;
    }
    
    // Wood materials (brown tones)
    else if (color.r > 0.3 && color.g > 0.2 && color.b < 0.3 &&
             color.r > color.b && color.g > color.b) {
        mat.roughness = 0.9;
        mat.reflectance = 0.02;
    }
    
    // Stone/concrete materials (low saturation, medium brightness)
    else if (brightness > 0.2 && brightness < 0.6 &&
             abs(color.r - color.g) < 0.2 && abs(color.g - color.b) < 0.2) {
        mat.roughness = 0.95;
        mat.reflectance = 0.02;
    }
    
    // Fabric/wool materials (soft, matte)
    else if (brightness > 0.4 && brightness < 0.9) {
        mat.roughness = 1.0;
        mat.reflectance = 0.01;
    }
    
    return mat;
}

// Fresnel calculation
float fresnel(vec3 viewDir, vec3 normal, float f0) {
    float cosTheta = max(0.0, dot(-viewDir, normal));
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

// Enhanced Blinn-Phong with energy conservation
float blinnPhong(vec3 lightDir, vec3 viewDir, vec3 normal, float shininess) {
    vec3 halfVector = normalize(lightDir - viewDir);
    float NdotH = max(0.0, dot(normal, halfVector));
    float normalizationFactor = (shininess + 8.0) / (8.0 * 3.14159);
    return pow(NdotH, shininess) * normalizationFactor;
}

// Subsurface scattering approximation
vec3 calculateSubsurface(vec3 lightDir, vec3 normal, vec3 albedo, float subsurface) {
    if (subsurface < 0.01) return vec3(0.0);
    
    // Simple back-lighting effect
    float backLight = max(0.0, dot(-lightDir, normal));
    return albedo * backLight * subsurface * 0.5;
}

// Environment reflection
vec3 getEnvironmentReflection(vec3 normal, vec3 viewDir, float roughness) {
    vec3 reflectDir = reflect(viewDir, normal);
    
    // Roughness affects reflection clarity
    float mipLevel = roughness * 6.0; // Simulate mip mapping
    float skyFactor = max(0.0, reflectDir.y);
    
    vec3 envColor = mix(fogColor * 0.8, skyColor, skyFactor);
    
    // Add some noise for rough surfaces
    if (roughness > 0.3) {
        float noise = sin(worldPos.x * 10.0) * sin(worldPos.z * 10.0) * 0.1;
        envColor *= (1.0 + noise * roughness);
    }
    
    float timeVariation = sin(frameTimeCounter * 0.3 + worldPos.x * 0.1) * 0.1 + 0.9;
    return envColor * timeVariation * (1.0 - roughness * 0.5);
}

// Enhanced PBR lighting calculation
vec3 calculatePBRLighting(MaterialProperties mat, vec3 normal, vec3 viewDir, vec3 lightDir, vec3 lightColor) {
    float NdotL = max(0.0, dot(normal, lightDir));
    float NdotV = max(0.0, dot(normal, -viewDir));
    
    // Diffuse with energy conservation
    vec3 diffuse = mat.albedo * NdotL / 3.14159;
    
    // Subsurface scattering for organic materials
    vec3 subsurface = calculateSubsurface(lightDir, normal, mat.albedo, mat.subsurface);
    
    // Metallic workflow
    vec3 f0 = mix(vec3(mat.reflectance), mat.albedo, mat.metallic);
    
    // Fresnel
    float fresnelFactor = fresnel(viewDir, normal, mat.reflectance);
    
    // Specular
    float shininess = (1.0 - mat.roughness) * 256.0 + 1.0;
    float specular = blinnPhong(lightDir, viewDir, normal, shininess);
    
    // Environment reflection
    vec3 envReflection = vec3(0.0);
    if (mat.metallic > 0.1 || mat.reflectance > 0.05) {
        envReflection = getEnvironmentReflection(normal, viewDir, mat.roughness) * 
                       mix(fresnelFactor, mat.metallic, mat.metallic);
    }
    
    // Combine all components
    vec3 result = diffuse * (1.0 - mat.metallic) * lightColor;
    result += subsurface * lightColor;
    result += specular * f0 * lightColor * NdotL;
    result += envReflection * 0.3;
    
    // Add ambient term
    result += mat.albedo * 0.03 * (1.0 - mat.metallic);
    
    return result;
}

void main() {
    // Get base color
    vec4 albedoColor = texture(gtexture, texcoord) * glcolor;
    
    // Get enhanced material properties
    MaterialProperties mat = getMaterialProperties(albedoColor, blockId, windEffect);
    
    // Normalize normal and calculate view direction
    vec3 surfaceNormal = normalize(normal);
    vec3 viewDir = normalize(viewPos);
    
    // Light setup
    bool isDay = worldTime > 1000 && worldTime < 13000;
    vec3 lightPos = isDay ? sunPosition : moonPosition;
    vec3 lightDir = normalize(lightPos);
    
    // Enhanced light color with atmospheric effects
    vec3 lightColor;
    if (isDay) {
        float dayProgress = (float(worldTime) - 1000.0) / 12000.0;
        float sunHeight = sin(dayProgress * 3.14159);
        lightColor = mix(vec3(1.0, 0.6, 0.3), vec3(1.0, 1.0, 0.95), sunHeight);
    } else {
        lightColor = vec3(0.2, 0.25, 0.4); // Cool moonlight
    }
    
    // Weather effects on lighting
    lightColor *= (1.0 - rainStrength * 0.4);
    
    // Calculate enhanced PBR lighting
    vec3 finalColor = calculatePBRLighting(mat, surfaceNormal, viewDir, lightDir, lightColor);
    
    // Apply lightmap with enhanced contrast
    vec3 lightmapColor = texture(lightmap, lmcoord).rgb;
    lightmapColor = pow(lightmapColor, vec3(0.8)); // Increase contrast
    finalColor *= lightmapColor;
    
    // Wind animation affects lighting slightly (leaves flicker)
    if (windEffect > 0.5) {
        float flicker = sin(frameTimeCounter * 8.0 + worldPos.x + worldPos.z) * 0.05 + 1.0;
        finalColor *= flicker;
    }
    
    color = vec4(finalColor, albedoColor.a);
    
    if (color.a < alphaTestRef) {
        discard;
    }
}