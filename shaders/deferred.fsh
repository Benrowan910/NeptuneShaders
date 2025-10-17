#version 330 compatibility

// Uniforms
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D lightmap;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 fogColor;
uniform vec3 skyColor;

// Inputs from vertex shader
in vec2 texcoord;
in vec3 lightDir;
in vec3 lightColor;
in float timeOfDay;

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Atmospheric scattering approximation
vec3 calculateAtmosphere(vec3 viewDir, vec3 lightDir, float depth) {
    float cosTheta = dot(viewDir, lightDir);
    
    // Rayleigh scattering (blue sky)
    float rayleigh = 1.0 + cosTheta * cosTheta;
    
    // Mie scattering (sun glow)
    float mie = 1.0 / pow(1.0 + 1.0 - cosTheta, 1.5);
    
    // Combine scattering (reduced intensity)
    vec3 scattering = vec3(0.15, 0.3, 0.5) * rayleigh + vec3(0.5, 0.45, 0.35) * mie * 0.05;
    
    // Apply depth-based fog
    float fogFactor = 1.0 - exp(-depth * 0.00001);
    
    return scattering * fogFactor * 0.5; // Further reduced
}

// Enhanced tone mapping
vec3 toneMapping(vec3 color) {
    // Filmic tone mapping
    vec3 x = max(vec3(0.0), color - vec3(0.004));
    return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

// Contrast and saturation enhancement
vec3 enhanceColors(vec3 color, float contrast, float saturation) {
    // Contrast
    color = (color - 0.5) * contrast + 0.5;
    
    // Saturation
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luminance), color, saturation);
    
    return color;
}

void main() {
    // Sample the original color
    vec4 originalColor = texture(colortex0, texcoord);
    
    // Sample depth
    float depth = texture(depthtex0, texcoord).r;
    
    // Calculate view space position
    vec4 clipPos = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clipPos;
    viewPos /= viewPos.w;
    
    // Calculate world space position
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    
    // View direction
    vec3 viewDir = normalize(viewPos.xyz);
    
    // Start with original color
    vec3 finalColor = originalColor.rgb;
    
    // Add atmospheric effects for distant objects
    if (depth > 0.99) {
        // Sky rendering
        vec3 atmosphere = calculateAtmosphere(viewDir, lightDir, 1000.0);
        finalColor = mix(finalColor, atmosphere, 0.5);
    } else {
        // Add subtle atmospheric perspective
        float distance = length(viewPos.xyz);
        vec3 atmosphere = calculateAtmosphere(viewDir, lightDir, distance);
        float atmosphereFactor = clamp(distance * 0.0001, 0.0, 0.3);
        finalColor = mix(finalColor, atmosphere, atmosphereFactor);
    }
    
    // Weather effects
    if (rainStrength > 0.1) {
        // Darker, more saturated colors during rain
        finalColor *= (1.0 - rainStrength * 0.3);
        finalColor = enhanceColors(finalColor, 1.2, 1.3);
    }
    
    // Time of day color grading
    if (timeOfDay > 0.2 && timeOfDay < 0.3) {
        // Sunrise - warm orange tint
        finalColor *= vec3(1.2, 1.0, 0.8);
    } else if (timeOfDay > 0.7 && timeOfDay < 0.8) {
        // Sunset - warm red tint
        finalColor *= vec3(1.3, 0.9, 0.7);
    } else if (timeOfDay > 0.9 || timeOfDay < 0.1) {
        // Night - cool blue tint
        finalColor *= vec3(0.7, 0.8, 1.2);
    }
    
    // Apply tone mapping and color enhancement
    finalColor = toneMapping(finalColor);
    finalColor = enhanceColors(finalColor, 1.1, 1.05);
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    color = vec4(finalColor, originalColor.a);
}