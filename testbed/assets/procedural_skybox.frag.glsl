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
  float sun_size;
};

layout(location = 0) out vec4 o_color;

void main() {
  // normalize the vertex position
  vec3 pos = normalize(dto.pos);
  // remap positions to uv on sphere
  vec2 uv = vec2(atan(pos.x, pos.y)/tau, asin(pos.z)/(pi/2));

  // base color gradient
  vec3 color = mix(horizon_color, sky_color, map(uv.y, 0, 1, 0.5, 1));

  float m_dist;
  vec2 m_point = vec2(0);
  vec2 tile_uv = uv * vec2(8, 2);
  voronoi(tile_uv, star_density, m_dist, m_point);
  color += vec3(pow(1-clamp(m_dist, 0, 1), 100));

  float sun_size2 = sun_size * sun_size;
  float d = dot(sun_dir, pos);
  color += vec3(1-smoothstep(sun_size2 - 0.01, sun_size2, acos(d)));

  o_color = vec4(color, 1.0);
}
