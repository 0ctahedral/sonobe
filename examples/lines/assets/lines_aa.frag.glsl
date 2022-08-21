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
  /*
  float dy = abs(dto.uv.y);
  float dx = min(abs(dto.uv.x), abs(dto.uv.x - dto.len));

  float d = dy;
  if (dto.uv.x < 0 || dto.uv.x > dto.len) {
    d = sqrt((dx * dx) + (dy * dy));
  }
  float aa = 0.01;
  float t = (dto.thickness / 2) - aa;
  // float c = step(d, );
  // if (c < 0.1) discard;
  
  d -= t;
  if (d < 0) {
    o_color = dto.color;
  } else {
    d /= aa;
    float a = exp(-d*d)*dto.color.a;
    if (a < 0.1) discard;
    o_color = vec4(dto.color.rgb * a, 1);
  }
  */
  o_color = vec4(dto.color.rgb, 1);
}
