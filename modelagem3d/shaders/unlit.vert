#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 2) in mat4 iModel;

uniform mat4 uView;
uniform mat4 uProj;
uniform mat4 uModel;
uniform bool uInstanced;

void main() {
    mat4 M = uInstanced ? iModel : uModel;
    gl_Position = uProj * uView * M * vec4(aPos, 1.0);
}