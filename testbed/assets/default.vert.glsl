#version 450
#extension GL_ARB_separate_shader_objects : enable


layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_texcoord;


// global data
layout (set = 0, binding = 0) uniform readonly global_uniform_object {
  mat4 projection;
  mat4 view;
  mat4 model;
};

// material data
layout (set = 1, binding = 0) uniform readonly material_data {
  vec2 tiling;
};

// layout( push_constant ) uniform PushConstants
// {
// 	uint id;
//   mat4 model;
// } pc;

// data transfer object
layout(location = 0) out struct {
  vec2 tex_coord;
} out_dto;

void main() {
  out_dto.tex_coord = in_texcoord * tiling;
  gl_Position = projection * view * model * vec4(in_pos, 1.0);
}
