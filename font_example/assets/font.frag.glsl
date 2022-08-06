#version 450
#extension GL_ARB_separate_shader_objects : enable
layout (set = 0, binding = 1) uniform texture2D tex;
layout (set = 0, binding = 2) uniform sampler samp;

layout(location = 0) in struct {
  vec2 uv;
  vec4 bb;
  vec4 rect;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  // glyph color
  vec3 color = vec3(1);

  // dummy data for this guy
  // texture resolution
  vec2 res = vec2(16, 16);

  vec2 uv = (dto.uv + vec2(0, res.y - 1)) * (dto.bb.xy / res) + dto.bb.zw / res;

  float a = texture(sampler2D(tex, samp), uv).r;

  // draw an outline using the rectangle coords
  vec2 f = dto.rect.zw * dto.uv;
  a += step(f.x, 1) + step(f.y, 1) + step(dto.rect.z - 1, f.x) + step(dto.rect.w - 1, f.y);

  o_color = vec4(color, a);
  // o_color = vec4(vec3(texture(sampler2D(tex, samp), dto.uv)), 1.0);

}
