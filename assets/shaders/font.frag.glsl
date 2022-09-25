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
  vec4 color;
} dto;

layout(location = 0) out vec4 o_color;

layout( push_constant ) uniform PushConstants
{
  uint mode;
} pc;

void main() {
  vec4 color = dto.color;
  vec2 uv = dto.uv;
  float a = texture(sampler2D(tex, samp), uv).r;

  // float a = texture(sampler2D(tex, samp), uv).r;
  switch (pc.mode) {
    case 1: 
      // draw an outline using the rectangle coords
      // vec2 f = dto.rect.zw * dto.uv;
      // a += step(f.x, 1) + step(f.y, 1) + step(dto.rect.z - 1, f.x) + step(dto.rect.w - 1, f.y);
      vec2 bounds = vec2(24, 48);
      vec2 f = bounds * dto.uv;
      a += step(f.x, 1) + step(f.y, 1) + step(bounds.x - 1, f.x) + step(bounds.y - 1, f.y);
      break;
    case 2:
      a = 1;
      break;
    case 3:
      color = vec4(uv, 0.0, 1.0);
      color += a;
      a = 1;
      break;
    default: break;
  }

  o_color = color * a;
}
