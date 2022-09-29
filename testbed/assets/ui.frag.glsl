#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in struct {
  vec4 color;
  vec2 uv;
} dto;
layout(location = 2) in flat uint o_type;

layout(location = 0) out vec4 o_color;

void main() {
  o_color = dto.color;
}
