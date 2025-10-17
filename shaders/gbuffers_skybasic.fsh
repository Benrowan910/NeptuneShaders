#version 330 compatibility

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float frameTimeCounter;
uniform float rainStrength;

in vec4 glcolor;

// Enhanced sky color calculation with atmospheric scattering
vec3 calculateAtmosphericScattering(vec3 viewDir, vec3 lightDir, bool isDay) {
    float cosTheta = dot(viewDir, lightDir);
    
    // Rayleigh scattering (blue sky)
    float rayleigh = 3.0 / (16.0 * 3.14159) * (1.0 + cosTheta * cosTheta);
    
    // Mie scattering (sun/moon glow and haze)
    float mie = 1.0 / (4.0 * 3.14159) * (1.0 - 0.9 * 0.9) / pow(1.0 + 0.9 * 0.9 - 2.0 * 0.9 * cosTheta, 1.5);
    
    // Base sky colors
    vec3 rayleighColor = isDay ? vec3(0.3, 0.6, 1.0) : vec3(0.1, 0.15, 0.3);
    vec3 mieColor = isDay ? vec3(1.0, 0.9, 0.7) : vec3(0.8, 0.8, 1.0);
    
    // Time-based color variations
    if (isDay) {
        float dayProgress = (float(worldTime) - 1000.0) / 12000.0;
        float sunHeight = sin(dayProgress * 3.14159);
        
        // Sunrise/sunset effects
        if (sunHeight < 0.3) {
            rayleighColor = mix(vec3(1.0, 0.4, 0.2), rayleighColor, sunHeight / 0.3);
            mieColor = mix(vec3(1.0, 0.6, 0.3), mieColor, sunHeight / 0.3);
        }
    }
    
    // Weather effects
    if (rainStrength > 0.1) {
        rayleighColor *= (1.0 - rainStrength * 0.6);
        mieColor *= (1.0 - rainStrength * 0.4);
    }
    
    return rayleighColor * rayleigh + mieColor * mie * 0.1;
}

// Enhanced horizon glow
vec3 calculateHorizonGlow(vec3 viewDir, vec3 lightDir, bool isDay) {
    float horizonFactor = 1.0 - abs(viewDir.y);
    float lightAlignment = max(0.0, dot(normalize(vec3(viewDir.x, 0.0, viewDir.z)), normalize(vec3(lightDir.x, 0.0, lightDir.z))));
    
    vec3 glowColor = isDay ? vec3(1.0, 0.8, 0.6) : vec3(0.8, 0.8, 1.0);
    float glowIntensity = pow(horizonFactor, 2.0) * pow(lightAlignment, 4.0);
    
    return glowColor * glowIntensity * 0.5;
}

// Cloud simulation
vec3 addClouds(vec3 skyColor, vec3 viewDir, float time) {
    // Simple procedural clouds
    vec2 cloudCoord = viewDir.xz / max(0.1, viewDir.y) * 0.1;
    
    float cloudNoise = 0.0;
    cloudNoise += sin(cloudCoord.x * 3.0 + time * 0.1) * cos(cloudCoord.y * 2.0 + time * 0.08) * 0.5;
    cloudNoise += sin(cloudCoord.x * 6.0 + time * 0.15) * cos(cloudCoord.y * 4.0 + time * 0.12) * 0.25;
    cloudNoise += sin(cloudCoord.x * 12.0 + time * 0.2) * cos(cloudCoord.y * 8.0 + time * 0.18) * 0.125;
    
    float cloudDensity = max(0.0, cloudNoise + 0.2);
    cloudDensity *= (1.0 + rainStrength * 2.0); // More clouds during rain
    
    vec3 cloudColor = vec3(0.9, 0.9, 0.95) * (0.8 - rainStrength * 0.4);
    
    return mix(skyColor, cloudColor, clamp(cloudDensity, 0.0, 0.8));
}

float fogify(float x, float w) {
    return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
    bool isDay = worldTime > 1000 && worldTime < 13000;
    vec3 lightPos = isDay ? sunPosition : moonPosition;
    vec3 lightDir = normalize(lightPos);
    
    // Enhanced atmospheric scattering
    vec3 scattering = calculateAtmosphericScattering(pos, lightDir, isDay);
    
    // Horizon glow
    vec3 horizonGlow = calculateHorizonGlow(pos, lightDir, isDay);
    
    // Base sky gradient
    float upDot = dot(pos, gbufferModelView[1].xyz);
    vec3 baseSky = mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
    
    // Combine all effects
    vec3 finalSky = baseSky + scattering + horizonGlow;
    
    // Add clouds
    if (pos.y > 0.0) {
        finalSky = addClouds(finalSky, pos, frameTimeCounter);
    }
    
    return finalSky;
}

vec3 screenToView(vec3 screenPos) {
    vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
    vec4 tmp = gbufferProjectionInverse * ndcPos;
    return tmp.xyz / tmp.w;
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    if (renderStage == MC_RENDER_STAGE_STARS) {
        // Enhanced star rendering
        vec4 starColor = glcolor;
        
        // Twinkle effect
        float twinkle = sin(frameTimeCounter * 8.0 + gl_FragCoord.x * 0.1 + gl_FragCoord.y * 0.1) * 0.2 + 0.8;
        starColor.rgb *= twinkle;
        
        // Fade stars during day and rain
        bool isDay = worldTime > 1000 && worldTime < 13000;
        if (isDay) {
            starColor.a *= 0.1;
        }
        starColor.a *= (1.0 - rainStrength * 0.8);
        
        color = starColor;
    } else {
        vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
        color = vec4(calcSkyColor(normalize(pos)), 1.0);
    }
}
