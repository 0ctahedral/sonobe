#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec3 v_pos;
layout(location = 1) in vec3 v_color;

layout(location = 0) out vec4 o_color;

void main() {
    o_color = vec4(v_color, 1.0);
}
