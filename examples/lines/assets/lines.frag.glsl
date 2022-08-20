#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in struct {
  vec4 color;
  vec2 uv;
  float feather;
  float thickness;
  float len;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  o_color = dto.color;
}
