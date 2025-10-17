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
out float windEffect;

// Function to detect foliage/leaves for wind animation
bool isFoliage(float entityId, vec3 color) {
    // Check if it's likely foliage based on color (green-ish) and entity type
    return (color.g > color.r && color.g > color.b && color.g > 0.3) || 
           (entityId >= 18.0 && entityId <= 19.0); // Leaf block IDs (approximate)
}

// Wind animation for foliage
vec3 applyWindAnimation(vec3 position, float time, float strength) {
    vec3 wind = vec3(0.0);
    
    // Primary wind wave
    wind.x += sin(time * 2.0 + position.x * 0.1 + position.z * 0.1) * strength;
    wind.z += cos(time * 1.8 + position.x * 0.1 + position.z * 0.1) * strength * 0.7;
    
    // Secondary smaller waves for detail
    wind.x += sin(time * 4.0 + position.y * 0.2) * strength * 0.3;
    wind.y += sin(time * 3.0 + position.x * 0.05) * strength * 0.2;
    
    // Gusts during rain
    if (rainStrength > 0.1) {
        float gustStrength = rainStrength * 2.0;
        wind.x += sin(time * 6.0 + position.x * 0.2) * gustStrength;
        wind.z += cos(time * 5.5 + position.z * 0.2) * gustStrength;
    }
    
    return wind;
}

void main() {
    // Calculate world position for wind effects
    vec4 modelViewPos = gl_ModelViewMatrix * gl_Vertex;
    vec4 worldPosition = gbufferModelViewInverse * modelViewPos;
    worldPos = worldPosition.xyz + cameraPosition;
    
    // Extract block ID and check for foliage
    blockId = mc_Entity.x;
    bool isLeaf = isFoliage(blockId, gl_Color.rgb);
    
    // Create a copy of the vertex for wind animation
    vec4 animatedVertex = gl_Vertex;
    
    // Apply wind animation to foliage
    if (isLeaf) {
        float windStrength = 0.02 + rainStrength * 0.03;
        vec3 windOffset = applyWindAnimation(worldPos, frameTimeCounter, windStrength);
        animatedVertex.xyz += windOffset;
        windEffect = 1.0;
    } else {
        windEffect = 0.0;
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