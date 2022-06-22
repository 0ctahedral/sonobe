#version 450
#extension GL_ARB_separate_shader_objects : enable

// THIS IS THE TARGET OF OUR GENERATED CODE

// TODO: this should be gone
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_texcoord;


// maybe have global data for all shaders?
layout (set = 0, binding = 0) uniform readonly global_uniform_object {
  mat4 projection;
  mat4 view;
};

// constants lookup buffer?

// constants buffer
layout (set = 0, binding = 1) readonly buffer PositionsBuffer {
  float pos[];
} Positions[];

layout (set = 0, binding = 1) readonly buffer TexcoordsBuffer {
  vec3 coord[];
} Texcoords[];

layout( push_constant ) uniform PushConstants
{
	uint id;
  mat4 model;
} pc;

// vertex data will be generated
// vec3 get_pos() {
//   return vec3(
//     Positions[0].pos[(gl_VertexIndex * 3) + 0],
//     Positions[0].pos[(gl_VertexIndex * 3) + 1],
//     Positions[0].pos[(gl_VertexIndex * 3) + 2]
//   );
// }
// 
// vec2 get_uv() {
//   return vec2(
//     Texcoords[1].coord[(gl_VertexIndex * 2) + 0],
//     Texcoords[1].coord[(gl_VertexIndex * 2) + 1]
//   );
// }
// 
// mat4 get_model() {
//   return pc.model;
// }

// data transfer object
layout(location = 0) out struct {
  vec2 tex_coord;
} out_dto;

struct Output {
  vec4 position;
  vec2 uv;
};

void main() {
//  out_dto.tex_coord = in_texcoord;
//
//  vec3 pos = Texcoords[0].coord[0];
//
//  gl_Position = projection * view * model * vec4(in_pos, 1.0);    

  Output vs_out;

  // imports:
  // pos: vec3
  // uv: vec2
  // --- global so maybe this is free? ---
  // view: mat4
  // projection: mat4

  // exports:
  // uv: vec2
  // position: vec4 (inherent?)

  // our actual code
  // vs_out.uv = get_uv();
  vs_out.uv = in_texcoord;
  // vs_out.position = projection * view * get_model() * vec4(get_pos(), 1.0);
  vs_out.position = projection * view * pc.model * vec4(in_pos, 1.0);
  //----------------



  out_dto.tex_coord = vs_out.uv;
  gl_Position = vs_out.position;
}
