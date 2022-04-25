#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec4 o_color;
layout (location = 0) in vec3 inColor;

void main() {
    //o_color = vec4(0.0, 1.0, 0.0, 1.0);
    o_color = vec4(inColor, 1.0);
}
