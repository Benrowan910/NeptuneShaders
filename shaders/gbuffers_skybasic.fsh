#version 330 compatibility

uniform int worldTime;
uniform float rainStrength;

in vec4 glcolor;

void main() {
    // Simple sky color based on time of day
    vec3 skyColor = glcolor.rgb;
    
    // Time-based adjustments (simplified)
    if (worldTime > 1000 && worldTime < 13000) {
        // Day - enhance blue
        skyColor *= vec3(0.9, 0.95, 1.1);
    } else {
        // Night - darker blue
        skyColor *= vec3(0.4, 0.5, 0.8);
    }
    
    // Rain effects (simple darkening)
    if (rainStrength > 0.1) {
        skyColor *= (1.0 - rainStrength * 0.4);
        skyColor *= vec3(0.8, 0.9, 1.0); // Slight blue tint
    }
    
    gl_FragColor = vec4(skyColor, 1.0);
}
