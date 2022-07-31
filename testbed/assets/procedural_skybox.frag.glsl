#version 450
#extension GL_ARB_separate_shader_objects : enable
#include "common.glsl"

layout (set = 0, binding = 1) uniform textureCube cube;
layout (set = 0, binding = 2) uniform sampler samp;

layout(location = 0) in struct {
  vec3 pos;
} dto;

layout (set = 1, binding = 0) uniform readonly camera_data {
  mat4 projection;
  mat4 view;
};

layout (set = 0, binding = 0) uniform readonly skybox_data {
  vec3 sky_color;
  float star_density;
  vec3 horizon_color;
  float star_radius;
  vec3 sun_dir;
};

layout(location = 0) out vec4 o_color;

void main() {
  vec3 pos = normalize(dto.pos);
  // remap positions to a sphere
  vec2 uv = vec2(atan(pos.x, pos.y)/tau, asin(pos.z)/(pi/2));
  // base color
  vec3 color = mix(horizon_color, sky_color, uv.y);

  float m_dist;
  float c;
  vec2 m_point = vec2(0);
  // which one is better?
  // Unity_Voronoi_float(uv * vec2(8, 2), 50, star_density, m_dist, c);
  vec2 tile_uv = uv * vec2(8, 2);
  voronoi(tile_uv, star_density, m_dist, m_point);
  color += vec3(pow(1-clamp(m_dist, 0, 1), 100));

  // normalize sun dir
  vec3 view_dir = vec3(mat4(mat3(view)) * vec4(0, 1, 0, 1));
  dot(sun_dir, normalize(view_dir));

  // draw_uv(tile_uv, vec3(0, 0.3, 0), color);


  o_color = vec4(color, 1.0);
}
