#version 330 compatibility

// Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

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
out float itemId;

void main() {
    // Calculate world position
    vec4 worldPosition = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    worldPos = worldPosition.xyz + cameraPosition;
    
    // View position (closer to camera for hand items)
    vec4 viewPosition = gbufferModelView * (worldPosition - vec4(cameraPosition, 0.0));
    viewPos = viewPosition.xyz;
    
    // Transform to clip space
    gl_Position = gbufferProjection * viewPosition;
    
    // Calculate normal in world space
    vec3 worldNormal = normalize(gl_NormalMatrix * gl_Normal);
    normal = worldNormal;
    
    // Pass through texture coordinates and lighting
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    
    // Item ID for material classification
    itemId = mc_Entity.x;
}