#version 450
#extension GL_ARB_separate_shader_objects : enable
layout (set = 0, binding = 1) uniform texture2D tex;
layout (set = 0, binding = 2) uniform sampler samp;
// layout (set = 0, binding = 0) uniform readonly tex_data {
// 
// };

layout(location = 0) in struct {
  vec2 uv;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  // glyph color
  vec3 color = vec3(1);

  // dummy data for this guy
  // texture resolution
  vec2 res = vec2(16, 16);
  // glyph offset in texture
  vec2 off = vec2(0, 1);
  // glyph bounding box
  vec2 bb = vec2(3, 9);

  // draw the glyph with alpha channel
  vec2 uv = dto.uv * (bb / res);
  uv += off / res;

  float a = texture(sampler2D(tex, samp), uv).r;

  // grid
  // vec2 f = fract(dto.uv * bb);
  // a += step(.9, f.x) + step(.9, f.y);


  o_color = vec4(color, a);
}
