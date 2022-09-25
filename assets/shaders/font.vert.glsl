#version 450
#extension GL_ARB_separate_shader_objects : enable

struct glyph_data {
  vec4 rect;
  vec4 color;
  // -- extra data
  vec2 bb;
  uint off;
  float ratio;
};

layout (set = 0, binding = 0) readonly buffer tex_data {
  mat4 projection;
  vec2 res;
  vec2 cell;
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
  vec4 color;
} out_dto;

void main() {
  uint corner = (gl_VertexIndex >> 24) & 0xf;
  uint idx = gl_VertexIndex & 0x00ffffff;
  vec4 rect = glyphs[idx].rect;

  vec2 pos[4] = vec2[](
    rect.xy + vec2(0, rect.w),
    rect.xy + vec2(rect.z, rect.w),
    rect.xy + vec2(rect.z, 0),
    rect.xy
  );

  vec2 n_cell = vec2(20, 10);
  vec2 uv_cell = 1 / n_cell;

  float linear_off = glyphs[idx].off;
  vec2 off = vec2(
      mod(linear_off, n_cell.x),
      floor(linear_off / n_cell.x)
  );
  // either one of these works
  vec2 glyph_rect = (rect.zw / glyphs[idx].ratio);
  glyph_rect = glyphs[idx].bb;

  vec2 uv_off = (off  * uv_cell);
  uv_off.y += (cell.y - glyph_rect.y) / res.y;

  out_dto.uv = uv_off + (uvs[corner] * glyph_rect / res);

  out_dto.color = glyphs[idx].color;

  gl_Position = projection  * vec4(pos[corner], 0.0, 1.0 );
}
