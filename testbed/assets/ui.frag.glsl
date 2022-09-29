#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (set = 0, binding = 3) uniform texture2D tex;
layout (set = 0, binding = 4) uniform sampler samp;

layout(location = 0) in struct {
  vec4 color;
  vec2 uv;
} dto;
layout(location = 2) in flat uint type;

layout(location = 0) out vec4 o_color;

void main() {
  vec4 color = dto.color;
  vec2 uv = dto.uv;
  float a = texture(sampler2D(tex, samp), uv).r;
  
  if (type == 1) {
    o_color = vec4(0,1,0,1);
  } else {
    a = 1;
  }


  o_color = color * a;
}
