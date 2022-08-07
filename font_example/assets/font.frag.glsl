#version 450
#extension GL_ARB_separate_shader_objects : enable
layout (set = 0, binding = 1) uniform texture2D tex;
layout (set = 0, binding = 2) uniform sampler samp;

layout (set = 0, binding = 0) readonly buffer tex_data {
  mat4 projection;
  vec2 res;
  vec2 cell;
};

layout(location = 0) in struct {
  vec2 uv;
  vec4 bb;
  vec4 rect;
} dto;

layout(location = 0) out vec4 o_color;

layout( push_constant ) uniform PushConstants
{
  uint mode;
} pc;

void main() {
  // TODO: glyph color
  vec3 color = vec3(1);

  vec4 bb = dto.bb;

  vec2 uv = (dto.uv * bb.xy) / res;
  uv.y += (bb.w + (cell.y - bb.y))/ res.y;
  uv.x += bb.z / res.x;

  float a = texture(sampler2D(tex, samp), uv).r;

  switch (pc.mode) {
    case 1: 
      // draw an outline using the rectangle coords
      vec2 f = dto.rect.zw * dto.uv;
      a += step(f.x, 1) + step(f.y, 1) + step(dto.rect.z - 1, f.x) + step(dto.rect.w - 1, f.y);
      break;
    case 2:
      a = 1;
      break;
    case 3:
      color = vec3(uv, 0.0);
      a = 1;
      break;
    default: break;
  }

  o_color = vec4(color, a);
}
