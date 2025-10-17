#version 330 compatibility

// Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

// Attributes
attribute vec4 mc_Entity;
attribute vec3 mc_midTexCoord;

// Outputs
out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 worldPos;
out vec3 viewPos;
out vec3 normal;
out float blockId;
out float foliageType;

// Function to detect foliage types
float detectFoliageType(float entityId, vec3 color, vec3 position) {
    // Check for leaves based on color (green-ish) and position
    bool isGreenish = (color.g > color.r && color.g > color.b && color.g > 0.3);
    bool isHighUp = position.y > 70.0; // Leaves are typically higher up
    
    if (isGreenish && isHighUp) {
        return 1.0; // Tree leaves
    } else if (isGreenish && !isHighUp) {
        return 0.5; // Grass/bushes
    }
    
    return 0.0; // Not foliage
}

// Advanced wind animation for different foliage types
vec3 applyWindAnimation(vec3 position, float time, float foliageType, float strength) {
    if (foliageType < 0.1) return vec3(0.0); // No animation for non-foliage
    
    vec3 wind = vec3(0.0);
    
    if (foliageType > 0.8) {
        // Tree leaves - complex multi-layered movement
        
        // Primary wind wave (large movement)
        wind.x += sin(time * 1.5 + position.x * 0.05 + position.z * 0.05) * strength * 2.0;
        wind.z += cos(time * 1.3 + position.x * 0.05 + position.z * 0.05) * strength * 1.5;
        
        // Secondary wave (medium frequency)
        wind.x += sin(time * 3.0 + position.y * 0.1) * strength * 0.8;
        wind.y += sin(time * 2.5 + position.x * 0.08) * strength * 0.4;
        wind.z += cos(time * 2.8 + position.z * 0.08) * strength * 0.6;
        
        // High frequency detail movement
        wind.x += sin(time * 8.0 + position.x * 0.2 + position.y * 0.1) * strength * 0.3;
        wind.y += cos(time * 7.0 + position.z * 0.15) * strength * 0.2;
        wind.z += sin(time * 9.0 + position.y * 0.2) * strength * 0.25;
        
        // Branch swaying (affects clusters of leaves)
        float branchPhase = sin(position.x * 0.02 + position.z * 0.02);
        wind.x += sin(time * 0.8 + branchPhase) * strength * 1.5;
        wind.y += cos(time * 0.6 + branchPhase) * strength * 0.8;
        
        // Storm effects
        if (rainStrength > 0.1) {
            float stormStrength = rainStrength * 3.0;
            wind.x += sin(time * 5.0 + position.x * 0.15) * stormStrength;
            wind.z += cos(time * 4.5 + position.z * 0.15) * stormStrength;
            wind.y += sin(time * 6.0) * stormStrength * 0.5;
        }
    } else {
        // Grass and low plants - gentler movement
        wind.x += sin(time * 3.0 + position.x * 0.1 + position.z * 0.1) * strength * 0.5;
        wind.z += cos(time * 2.8 + position.x * 0.1 + position.z * 0.1) * strength * 0.4;
        wind.y += sin(time * 4.0 + position.x * 0.05) * strength * 0.2;
        
        // Add some randomness
        wind.x += sin(time * 6.0 + position.y * 0.3) * strength * 0.2;
    }
    
    return wind;
}

void main() {
    // Calculate world position for wind effects
    vec4 modelViewPos = gl_ModelViewMatrix * gl_Vertex;
    vec4 worldPosition = gbufferModelViewInverse * modelViewPos;
    worldPos = worldPosition.xyz + cameraPosition;
    
    // Extract block ID and detect foliage
    blockId = mc_Entity.x;
    foliageType = detectFoliageType(blockId, gl_Color.rgb, worldPos);
    
    // Create a copy of the vertex for wind animation
    vec4 animatedVertex = gl_Vertex;
    
    // Apply wind animation to foliage
    if (foliageType > 0.1) {
        float windStrength = 0.015 + rainStrength * 0.025;
        
        // Different wind strength for different foliage types
        if (foliageType > 0.8) {
            windStrength *= 1.5; // Stronger for tree leaves
        } else {
            windStrength *= 0.7; // Gentler for grass
        }
        
        vec3 windOffset = applyWindAnimation(worldPos, frameTimeCounter, foliageType, windStrength);
        animatedVertex.xyz += windOffset;
    }
    
    // Use standard transformation with animated vertex
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * animatedVertex;
    
    // View position
    viewPos = (gl_ModelViewMatrix * animatedVertex).xyz;
    
    // Calculate normal in world space
    vec3 worldNormal = normalize(gl_NormalMatrix * gl_Normal);
    normal = worldNormal;
    
    // Pass through texture coordinates and lighting
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
}