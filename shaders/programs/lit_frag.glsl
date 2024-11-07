#version 460

//uniform vec3 uPointLightPosition;  
//uniform vec3 uPointLightColor;    
//uniform float uPointLightIntensity;
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform sampler2D normals;
uniform float far;
uniform sampler2D specular;
uniform sampler2D shadowtex0;
uniform vec3 cameraPosition;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

layout(location = 0) out vec4 outColor0;

in vec2 texCoord;
in vec3 foliageColor;
in vec2 lightMapCoords;
in vec3 geoNormal;
in vec4 tangent;
in vec3 viewSpacePosition;

#include "/programs/functions.glsl"

void main(){

    vec4 outputColorData = texture(gtexture,texCoord);
    vec3 albedo = pow(outputColorData.rgb, vec3(2.2))  * pow(foliageColor,vec3(2.2));
    float transparency = outputColorData.a;
    if(transparency < .1){
        discard;
    }

    vec3 outputColor = lightingCalculations(albedo);
    float distanceFromCamera = distance(viewSpacePosition,vec3(0));
    float blend = smoothstep (far-.5*far,far, distanceFromCamera);
    transparency = mix(0.0, transparency,pow((1-blend),.6));
    outColor0 = vec4(pow(outputColor, vec3(1/2.2)), transparency);
}