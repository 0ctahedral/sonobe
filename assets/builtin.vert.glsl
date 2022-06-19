#version 450
#extension GL_ARB_separate_shader_objects : enable

// vertex data
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_texcoord;

layout (set = 0, binding = 0) uniform readonly global_uniform_object {
  mat4 projection;
  mat4 view;
};

layout (set = 0, binding = 1) readonly buffer PositionsBuffer {
  vec3 pos[];
} Positions[];

layout (set = 0, binding = 1) readonly buffer TexcoordsBuffer {
  float coord[];
} Texcoords[];

layout( push_constant ) uniform PushConstants
{
	uint id;
  mat4 model;
};

// data transfer object
layout(location = 0) out struct {
  vec2 tex_coord;
} out_dto;

void main() {
  out_dto.tex_coord = in_texcoord;
  // if (gl_VertexIndex == 2) {
  //   out_dto.tex_coord = vec2(
  //       Texcoords[1].coord[gl_VertexIndex * 2],
  //       Texcoords[1].coord[(gl_VertexIndex * 2) + 1]
  //   );
  // }

  gl_Position = projection * view * model * vec4(Positions[0].pos[gl_VertexIndex], 1.0);
}
