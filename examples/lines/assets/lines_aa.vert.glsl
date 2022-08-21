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

vec2 resolution = vec2(600, 800);

/*
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


float estimate_width(vec3 position, vec2 sPosition, float width)
{
    vec4 view_pos = view * vec4(position, 1.0);
    vec4 scale_pos = view_pos - vec4(normalize(view_pos.xy)*width, 0.0, 1.0);
    vec2 screen_scale_pos = project(proj* scale_pos);
    return distance(sPosition, screen_scale_pos);
}
*/
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
    vec2((d *len)+d, d),
    vec2((d * len)+d, -d)
  );

  // set our attrs
  out_dto.color = line.color;
  out_dto.uv = uvs[corner];
  out_dto.feather = line.feather;
  out_dto.thickness = line.thickness;
  out_dto.len = len * d;

  mat4 viewproj = proj * view;

  vec3 positions[4] = vec3[](
    vec3(0, -1, -1),
    vec3(0,  1, -1),
    vec3(1, -1, +1), //+d),
    vec3(1,  1, +1)  //+d)
  );

  vec3 position = positions[corner];

  // start position in projection space
  vec4 start_clip = viewproj * vec4(line.start, 1.0 );
  // end position in projection space
  vec4 end_clip = viewproj * vec4(line.end, 1.0 );

  vec2 start_screen = resolution * (0.5 * start_clip.xy/start_clip.w + 0.5);
  vec2 end_screen = resolution * (0.5 * end_clip.xy/end_clip.w + 0.5);

  vec2 xbasis = normalize(end_screen - start_screen);
  vec2 ybasis = vec2(-xbasis.y, xbasis.x);

  vec2 pt0 = start_screen + line.thickness * (position.z * xbasis + position.y * ybasis);
  vec2 pt1 = end_screen + line.thickness * (position.z * xbasis + position.y * ybasis);
  vec2 pt = mix(pt0, pt1, position.x);

  vec4 clip_dir = normalize(end_clip - start_clip);

  vec4 clip = mix(start_clip, end_clip, position.x);
  //vec4 clip = start_clip + (clip_dir * position.x);

  gl_Position = vec4(clip.w * ((2.0 * pt) / resolution - 1.0), clip.z, clip.w);
}
