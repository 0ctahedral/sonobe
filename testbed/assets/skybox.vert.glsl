#version 450
#extension GL_ARB_separate_shader_objects : enable


layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_texcoord;


// global data
layout (set = 0, binding = 0) uniform readonly camera_data {
  mat4 projection;
  mat4 view;
};


// data transfer object
layout(location = 0) out struct {
  vec3 uvw;
} out_dto;

void main() {
  out_dto.uvw = in_pos;
  gl_Position = projection * view * vec4(in_pos, 1.0);
}
