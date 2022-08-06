#version 450
#extension GL_ARB_separate_shader_objects : enable

struct glyph_data {
  vec4 rect;
  vec4 bb;
};

layout (set = 0, binding = 0) readonly buffer tex_data {
  mat4 projection;
  glyph_data glyphs[];
};

vec2 uvs[4] = vec2[](
  vec2(0.0, 0.0),
  vec2(1.0, 0.0),
  vec2(1.0, 1.0),
  vec2(0.0, 1.0)
);

// data transfer object
layout(location = 0) out struct {
  vec2 uv;
  vec4 bb;
  vec4 rect;
} out_dto;

void main() {
  uint corner = (gl_VertexIndex >> 24) & 0xf;
  uint idx = gl_VertexIndex & 0x00ffffff;
  vec4 rect = glyphs[idx].rect;

  vec2 pos[4] = vec2[](
    rect.xy,
    rect.xy + vec2(rect.z, 0),
    rect.xy + vec2(rect.z, -rect.w),
    rect.xy + vec2(0, -rect.w)
  );

  out_dto.uv = uvs[corner];
  out_dto.bb = glyphs[idx].bb;
  out_dto.rect = rect;
  gl_Position = projection  * vec4(pos[corner], 0.0, 1.0 );
}
