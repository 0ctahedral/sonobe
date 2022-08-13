#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in struct {
  vec4 color;
  vec2 uv;
  float feather;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  vec3 color = dto.color.rgb;
  float a = smoothstep(0, dto.feather, dto.color.a - abs((dto.uv.x * 2) - 1));
  o_color = vec4(color, a);
}
