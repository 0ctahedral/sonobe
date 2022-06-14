#version 450
#extension GL_ARB_separate_shader_objects : enable

// vertex data
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_texcoord;

// layout (set = 0, binding = 0) uniform readonly buffer global_uniform_object {
//   mat4 projection;
//   mat4 view;
// };

struct Camera {
  mat4 projection;
  mat4 view;
};

layout (set = 0, binding = 0) readonly buffer global_uniform_buffer {
  uint data[];
};

// layout(set = 0, binding = 1) readonly buffer  InputBuffer{
//     mat4 matrices[];
// } sourceData;

layout( push_constant ) uniform PushConstants
{
	uint id;
  mat4 model;
};

layout(location = 0) out vec3 output_mode;

// data transfer object
layout(location = 1) out struct {
  vec2 tex_coord;
} out_dto;

void main() {
  out_dto.tex_coord = in_texcoord;

  Camera camera = Camera(data[0])
  
  gl_Position = projection * camera.view * camera.model * vec4(in_pos, 1.0);    
}
