#version 460

uniform sampler2D gtexture;
uniform vec3 shadowLightPosition;

in vec2 fragUV;
in vec2 fragPosition;

layout(location = 0) out vec4 outColor0;

uniform float frameTimeCounter;

void main(){
    vec4 baseColor = texture(gtexture, fragUV);

    float rippleIntensity = 0.02;
    float rippleFreq = 8.0;
    vec2 ripple = vec2(
        sin(rippleFreq * fragUV.x + frameTimeCounter),
        sin(rippleFreq * fragUV.y + frameTimeCounter)
    );
    vec2 rippledUV = fragUV + ripple * rippleIntensity;

    vec4 rippledColor = texture(gtexture, rippledUV);

    outColor0 = mix(baseColor, rippledColor, 0.5);

    outColor0.rgb *= shadowLightPosition;
}
