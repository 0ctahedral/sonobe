#version 450
#extension GL_ARB_separate_shader_objects : enable

struct line_data {
  vec3 start;
  float thickness;
  vec3 end;
  float feather;
  vec4 color;
};

layout( push_constant ) uniform PushConstants
{
  mat4 viewproj;
  float aspect;
};

layout (set = 0, binding = 0) readonly buffer line_data_buffer {
  line_data lines[];
};

// data transfer object
layout(location = 0) out struct {
  vec4 color;
  vec2 uv;
  float feather;
} out_dto;

void main() {
  uint corner = (gl_VertexIndex >> 24) & 0xf;
  uint idx = gl_VertexIndex & 0x00ffffff;
  line_data line = lines[idx];

  // start position in projection space
  vec4 start_proj = viewproj * vec4(line.start, 1.0 );
  // start position in ndc space
  vec2 start_screen = start_proj.xy / start_proj.w;
  // correct aspect ratio
  start_screen.x *= aspect;
  // end position in projection space
  vec4 end_proj = viewproj * vec4(line.end, 1.0 );
  // end position in ndc space
  vec2 end_screen = end_proj.xy / end_proj.w;
  // correct aspect ratio
  end_screen.x *= aspect;

  vec2 dir = normalize(end_screen - start_screen);
  vec2 norm = vec2(-dir.y, dir.x);
  vec4 off = vec4(norm * (line.thickness / 2), 0, 0);
  off.x /= aspect;

  vec2 uv[4] = vec2[](
    vec2(0.0, 0.0),
    vec2(1.0, 0.0),
    vec2(1.0, 1.0),
    vec2(0.0, 1.0)
  );

  vec4 pos[4] = vec4[](
      start_proj - off,
      start_proj + off,
      end_proj + off,
      end_proj - off
  );

  out_dto.uv = uv[corner];
  out_dto.color = line.color;
  out_dto.feather = line.feather;
  gl_Position = pos[corner];
}
