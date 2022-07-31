#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (set = 0, binding = 1) uniform textureCube cube;
layout (set = 0, binding = 2) uniform sampler samp;

layout(location = 0) in struct {
  vec3 pos;
} dto;

layout (set = 0, binding = 0) uniform readonly camera_data {
  mat4 projection;
  mat4 view;
  vec4 sky_color;
  vec4 horizon_color;
};

layout(location = 0) out vec4 o_color;

#define pi 3.14159265359
#define tau 6.28318530718

void main() {

  vec3 pos = normalize(dto.pos);
  vec2 new_uv = vec2(atan(pos.x, pos.y)/tau, asin(pos.z)/(pi/2));

  // cube map sampling
  //o_color = texture(samplerCube(cube, samp), dto.pos);
  // square uv sampling
  //o_color = texture(sampler2D(tex, samp), new_uv);


  o_color = mix(horizon_color, sky_color, new_uv.y + 0.5);
  // o_color = vec4(new_uv, 0, 1.0);
}
