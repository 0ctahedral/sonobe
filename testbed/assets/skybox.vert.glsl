#version 450
#extension GL_ARB_separate_shader_objects : enable
// global data
layout (set = 0, binding = 0) uniform readonly camera_data {
  mat4 projection;
  mat4 view;
  vec4 albedo;
};


// data transfer object
layout(location = 0) out struct {
  vec3 pos;
} out_dto;

void main() {
  int i = gl_VertexIndex;
  vec3 pos = vec3(((i << 1) & 2), (i & 2), ((i >> 1) & 2)) - vec3(1);

  out_dto.pos = pos;
  gl_Position = projection * mat4(mat3(view)) * vec4(pos, 1.0);
}
