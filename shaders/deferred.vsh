#version 330 compatibility

// Uniforms
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;

// Outputs
out vec2 texcoord;
out vec3 lightDir;
out vec3 lightColor;
out float timeOfDay;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
    // Calculate time of day factor
    timeOfDay = float(worldTime) / 24000.0;
    
    // Determine light direction and color based on time
    bool isDay = worldTime > 1000 && worldTime < 13000;
    
    if (isDay) {
        lightDir = normalize(sunPosition);
        // Warmer light during sunrise/sunset
        float dayProgress = (float(worldTime) - 1000.0) / 12000.0;
        float sunHeight = sin(dayProgress * 3.14159);
        lightColor = mix(vec3(1.0, 0.6, 0.3), vec3(1.0, 1.0, 0.9), sunHeight);
    } else {
        lightDir = normalize(moonPosition);
        lightColor = vec3(0.3, 0.3, 0.5); // Cool moonlight
    }
}