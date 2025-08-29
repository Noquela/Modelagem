#version 330 core
in vec3 vNormal;
in vec3 vWorldPos;
out vec4 FragColor;

uniform vec3 uLightDir;    // normalizado
uniform vec3 uAlbedo;
uniform vec3 uAmbient;
uniform float uAlpha;

void main() {
    vec3 normal = normalize(vNormal);
    float ndl = max(dot(normal, -normalize(uLightDir)), 0.0);
    vec3 color = uAmbient * uAlbedo + ndl * uAlbedo;
    FragColor = vec4(color, uAlpha);
}