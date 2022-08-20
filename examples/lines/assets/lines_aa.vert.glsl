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
  mat4 view;
  mat4 proj;
  //mat4 viewproj;
  // float aspect;
};

layout (set = 0, binding = 0) readonly buffer line_data_buffer {
  line_data lines[];
};

// data transfer object
layout(location = 0) out struct {
  vec4 color;
  vec2 uv;
  float feather;
  float thickness;
  float len;
} out_dto;

vec2 viewport = vec2(600, 800);

vec2 project(vec4 P) {
  // TODO: make this a variable
  vec2 p = 0.5 + (P.xyz/P.w).xy * 0.5;
  return p * viewport;
}

// Project from the screen space to the world space
vec4 unproject(vec2 p, float z, float w)
{
    vec4 P = vec4( w*((p/viewport)*2.0 - 1.0), z, w);
    return P;
}

#define map(value, low1, high1, low2, high2) \
  low2 + (value - low1) * (high2 - low2) / (high1 - low1)

void main() {
  uint corner = (gl_VertexIndex >> 24) & 0xf;
  uint idx = gl_VertexIndex & 0x00ffffff;
  line_data line = lines[idx];


  // half the height of the resulting quad
  float d = ceil(line.thickness + (2.5 * line.feather));
  // this is the line length and direction in world space
  vec3 l = line.end - line.start;
  vec3 wdir = normalize(l);
  float len = length(l);

  vec2 uvs[4] = vec2[](
    vec2(-d, d),
    vec2(-d, -d),
    vec2(len+d, d),
    vec2(len+d, -d)
  );

  // set our attrs
  out_dto.color = line.color;
  out_dto.uv = uvs[corner];
  out_dto.feather = line.feather;
  out_dto.thickness = line.thickness;
  out_dto.len = len;

  mat4 viewproj = proj * view;

  float aspect = 800 / 600;

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
  //vec4 off = vec4(norm * d, 0, 0);
  //off.x /= aspect;
  vec4 rpos[4];
  rpos = vec4[](
      start_proj + vec4(-dir - norm, 0, 0) * d,
      start_proj + vec4(-dir + norm, 0, 0) * d,
      end_proj   + vec4(-dir - norm, 0, 0) * d,
      end_proj   + vec4(-dir + norm, 0, 0) * d
  );

  gl_Position = rpos[corner];
}
