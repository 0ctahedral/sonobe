#version 450
#extension GL_ARB_separate_shader_objects : enable

struct rect_data {
  vec4 rect;
  vec4 color;
};

struct glyph_data {
  vec2 bb;
  vec2 texel;
};

layout (set = 0, binding = 0)  uniform uniform_data_block {
  mat4 view_proj;
};

layout (set = 0, binding = 1) uniform rect_data_buf {
  rect_data rects[1024];
};

layout (set = 0, binding = 2) uniform glyph_data_buf {
  glyph_data glyphs[1024];
};

// data transfer object
layout(location = 0) out struct {
  vec4 color;
  vec2 uv;
} out_dto;

layout(location = 2) out flat uint o_type;


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
  vec4 rect = rects[idx].rect;


  vec2 pos[4] = vec2[](
    rect.xy + vec2(0, rect.w),
    rect.xy + vec2(rect.z, rect.w),
    rect.xy + vec2(rect.z, 0),
    rect.xy
  );

  out_dto.uv = uvs[corner];
  out_dto.color = rects[idx].color;
  o_type = type;

  // if (type == 1) {
  //   out_dto.uv = 
  // }

  gl_Position = view_proj * vec4(pos[corner], 0, 1.0);
}
