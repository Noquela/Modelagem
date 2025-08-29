#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in mat4 iModel;   // usado se instancing

uniform mat4 uView;
uniform mat4 uProj;
uniform mat4 uModel;
uniform bool uInstanced;

out vec3 vNormal;
out vec3 vWorldPos;

void main() {
    mat4 M = uInstanced ? iModel : uModel;
    vec4 wp = M * vec4(aPos, 1.0);
    vWorldPos = wp.xyz;
    vNormal = mat3(transpose(inverse(M))) * aNormal;
    gl_Position = uProj * uView * wp;
}