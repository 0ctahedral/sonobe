#version 450
#extension GL_ARB_separate_shader_objects : enable
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_texcoord;

layout (set = 0, binding = 0) readonly buffer tex_data {
  mat4 projection;
};

// data transfer object
layout(location = 0) out struct {
  vec2 uv;
} out_dto;

layout( push_constant ) uniform PushConstants
{
  mat4 model;
} pc;

void main() {
  out_dto.uv = in_texcoord;
  gl_Position = projection * pc.model * vec4(in_pos, 1.0);
}
