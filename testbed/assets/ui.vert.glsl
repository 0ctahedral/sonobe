#version 450
#extension GL_ARB_separate_shader_objects : enable

struct rect_data {
  vec4 rect;
  vec4 color;
};

layout (set = 0, binding = 0)  uniform uniform_data_block {
  mat4 view_proj;
};

layout (set = 1, binding = 0) readonly buffer rect_data_buf {
  rect_data data[1024];
};

// data transfer object
layout(location = 0) out struct {
  vec2 uv;
  vec4 color;
} out_dto;

vec2 uvs[4] = vec2[](
  vec2(0.0, 0.0),
  vec2(1.0, 0.0),
  vec2(1.0, 1.0),
  vec2(0.0, 1.0)
);

void main() {

  uint type = (gl_VertexIndex >> 26) & 0xf;
  uint corner = (gl_VertexIndex >> 24) & 0x3;
  uint idx = gl_VertexIndex & 0x00ffffff;
  vec4 rect = data[idx].rect;


  vec2 pos[4] = vec2[](
    rect.xy + vec2(0, rect.w),
    rect.xy + vec2(rect.z, rect.w),
    rect.xy + vec2(rect.z, 0),
    rect.xy
  );

  out_dto.uv = uvs[corner];
  out_dto.color = data[idx].color;

  gl_Position = view_proj * vec4(pos[corner], 0, 1.0);
}
