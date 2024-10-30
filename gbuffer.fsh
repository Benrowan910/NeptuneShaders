#version 460

uniform sampler2D gTexture;

layout(location = 0) out vec4 outColor;

in vec2 texCoord;

void main(){
    outColor = texture(gTexture, texCoord);
}