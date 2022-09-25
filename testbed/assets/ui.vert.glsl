#version 450
#extension GL_ARB_separate_shader_objects : enable

struct ui_data {
  vec4 rect;
  vec4 color;
};

layout (set = 0, binding = 0) readonly buffer ui_data_buf {
  mat4 view_proj;
  ui_data data[];
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

  uint corner = (gl_VertexIndex >> 24) & 0xf;
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
