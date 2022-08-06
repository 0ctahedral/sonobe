#version 450
#extension GL_ARB_separate_shader_objects : enable
layout (set = 0, binding = 1) uniform texture2D tex;
layout (set = 0, binding = 2) uniform sampler samp;

layout(location = 0) in struct {
  vec2 uv;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  // sample the texture like normal
  vec3 color = vec3(texture(sampler2D(tex, samp), dto.uv).r);

  // draw a grid of cells
  vec2 res = vec2(textureSize(sampler2D(tex, samp), 0));
  vec2 f = fract(dto.uv * vec2(20, 10));
  color.g += step(0.9,f.x) + step(0.95,1-f.y);

  o_color = vec4(color, 1.0);
}
