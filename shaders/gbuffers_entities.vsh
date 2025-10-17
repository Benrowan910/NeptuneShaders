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
flat out int entityId;

void main() {
    // Use standard transformation for position
    gl_Position = ftransform();
    
    // Calculate world position for effects
    vec4 modelViewPos = gl_ModelViewMatrix * gl_Vertex;
    vec4 worldPosition = gbufferModelViewInverse * modelViewPos;
    worldPos = worldPosition.xyz + cameraPosition;
    
    // View position
    viewPos = modelViewPos.xyz;
    
    // Calculate normal in world space
    vec3 worldNormal = normalize(gl_NormalMatrix * gl_Normal);
    normal = worldNormal;
    
    // Pass through texture coordinates and lighting
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    
    // Entity ID for material classification
    entityId = int(mc_Entity.x);
}