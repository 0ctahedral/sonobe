#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_texcoord;

layout( push_constant ) uniform PushConstants
{
  mat4 projection;
  mat4 model;
};

// data transfer object
layout(location = 0) out struct {
  vec2 uv;
} out_dto;

void main() {
  out_dto.uv = in_texcoord;
  gl_Position = projection *  model * vec4(in_pos.xyz, 1.0);
}
