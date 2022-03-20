#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec4 o_color;

void main() {
    o_color = vec4(1.0, 1.0, 0.0, 1.0);
}
