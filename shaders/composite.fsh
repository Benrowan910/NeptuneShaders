#version 330 compatibility

// Uniforms
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float frameTimeCounter;
uniform int worldTime;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float viewWidth;
uniform float viewHeight;

// Inputs
in vec2 texcoord;

// Outputs
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Noise function for film grain
float random(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Advanced color grading
vec3 colorGrade(vec3 color, float time) {
    // Time of day color grading
    float timeOfDay = float(worldTime) / 24000.0;
    
    // Sunrise (5000-7000)
    if (worldTime > 5000 && worldTime < 7000) {
        float sunriseFactor = (float(worldTime) - 5000.0) / 2000.0;
        vec3 sunriseColor = vec3(1.3, 0.9, 0.6);
        color *= mix(vec3(1.0), sunriseColor, sin(sunriseFactor * 3.14159) * 0.4);
    }
    
    // Day (7000-17000)
    else if (worldTime > 7000 && worldTime < 17000) {
        color *= vec3(1.05, 1.0, 0.98); // Slightly warm
    }
    
    // Sunset (17000-19000)
    else if (worldTime > 17000 && worldTime < 19000) {
        float sunsetFactor = (float(worldTime) - 17000.0) / 2000.0;
        vec3 sunsetColor = vec3(1.4, 0.8, 0.5);
        color *= mix(vec3(1.0), sunsetColor, sin(sunsetFactor * 3.14159) * 0.5);
    }
    
    // Night (19000-5000)
    else {
        vec3 nightColor = vec3(0.6, 0.7, 1.2);
        color *= nightColor;
    }
    
    // Weather color grading
    if (rainStrength > 0.1) {
        // Desaturate and darken during rain
        float luminance = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(color, vec3(luminance), rainStrength * 0.4);
        color *= (1.0 - rainStrength * 0.3);
        
        // Add slight blue tint
        color *= vec3(0.9, 0.95, 1.1);
    }
    
    return color;
}

// Enhanced tone mapping with exposure
vec3 toneMapping(vec3 color, float exposure) {
    // Exposure adjustment
    color *= exposure;
    
    // Filmic tone mapping (ACES approximation)
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    
    color = clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0);
    
    return color;
}

// Vignette effect
vec3 applyVignette(vec3 color, vec2 uv) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    
    // Gentle vignette
    float vignette = 1.0 - smoothstep(0.3, 0.8, dist);
    vignette = mix(0.7, 1.0, vignette);
    
    return color * vignette;
}

// Film grain
vec3 addFilmGrain(vec3 color, vec2 uv, float time) {
    float grain = random(uv + time * 0.1) * 0.02 - 0.01;
    return color + grain;
}

// Chromatic aberration
vec3 chromaticAberration(sampler2D tex, vec2 uv, float strength) {
    vec2 direction = (uv - 0.5) * strength;
    
    float r = texture(tex, uv + direction).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - direction).b;
    
    return vec3(r, g, b);
}

// Bloom effect (simple)
vec3 addBloom(sampler2D tex, vec2 uv) {
    vec3 bloom = vec3(0.0);
    float weights[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
    vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);
    
    // Horizontal blur
    for (int i = -4; i <= 4; i++) {
        vec2 offset = vec2(float(i) * texelSize.x, 0.0);
        vec3 sample = texture(tex, uv + offset).rgb;
        
        // Only bloom bright areas (increased threshold)
        float brightness = dot(sample, vec3(0.299, 0.587, 0.114));
        if (brightness > 1.2) {
            bloom += sample * weights[abs(i)];
        }
    }
    
    return bloom * 0.1; // Reduced bloom intensity
}

void main() {
    vec2 uv = texcoord;
    
    // Sample base color (simplified for Iris)
    vec3 baseColor = texture(colortex0, uv).rgb;
    
    // Reduced color grading for Iris compatibility
    if (worldTime > 1000 && worldTime < 13000) {
        // Day - neutral
        baseColor *= vec3(1.0, 1.0, 1.0);
    } else {
        // Night - slightly blue
        baseColor *= vec3(0.9, 0.9, 1.1);
    }
    
    // Simple exposure
    float exposure = 1.0;
    baseColor *= exposure;
    
    // Reduce saturation to fix over-saturation
    float luminance = dot(baseColor, vec3(0.299, 0.587, 0.114));
    baseColor = mix(vec3(luminance), baseColor, 0.8); // Reduced saturation
    
    // Simple gamma correction
    baseColor = pow(baseColor, vec3(1.0 / 2.2));
    
    color = vec4(baseColor, 1.0);
}