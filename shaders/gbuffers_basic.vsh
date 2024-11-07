#version 150 compatibility

// Uniforms for transformation matrices
uniform mat4 uProjectionMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uModelMatrix;

// Vertex attributes
in vec3 aPosition;
in vec3 aNormal;
in vec2 aTexCoord;

// Outputs to the fragment shader
out vec2 vTexCoord;
out vec3 vWorldPosition;
out vec3 vNormal;

void main() {
    // Transform position and normal
    vec4 worldPosition = uModelMatrix * vec4(aPosition, 1.0);
    vWorldPosition = worldPosition.xyz;
    vNormal = mat3(uModelMatrix) * aNormal; // Transform normal vector to world space
    vTexCoord = aTexCoord;

    // Final position
    gl_Position = uProjectionMatrix * uViewMatrix * worldPosition;
}
