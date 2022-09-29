#version 450
#extension GL_ARB_separate_shader_objects : enable

struct rect_data {
  vec4 r;
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
  glyph_data glyphs[200];
};

// data transfer object
layout(location = 0) out struct {
  vec4 color;
  vec2 uv;
} dto;

layout(location = 2) out flat struct {
  uint type;
} flat_dto;


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

  dto.uv = uvs[corner];
  flat_dto.type = type;

  rect_data rect;
  // set up uvs for font
  if (type == 1) {
    // extract the glyph idx 
    uint glyph_idx = (idx >> 16);
    uint rect_idx = gl_VertexIndex & 0x0000ffff;
    rect = rects[rect_idx];
    // TODO: put in uniform buffer
    vec2 cell = vec2(6, 12);
    vec2 res = vec2(120, 120);

    glyph_data gd = glyphs[glyph_idx];
    vec2 glyph_rect = gd.bb;
    vec2 uv_off = gd.texel/res;
    uv_off.y += (cell.y - glyph_rect.y) / res.y;

    dto.uv = uv_off + (uvs[corner] * glyph_rect / res);
  } else {
    rect = rects[idx];
  }

  dto.color = rect.color;




  vec2 pos[4] = vec2[](
    rect.r.xy + vec2(0, rect.r.w),
    rect.r.xy + vec2(rect.r.z, rect.r.w),
    rect.r.xy + vec2(rect.r.z, 0),
    rect.r.xy
  );

  gl_Position = view_proj * vec4(pos[corner], 0, 1.0);
}
