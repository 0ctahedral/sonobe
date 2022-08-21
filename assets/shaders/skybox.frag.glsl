#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (set = 0, binding = 1) uniform textureCube cube;
layout (set = 0, binding = 2) uniform sampler samp;

layout(location = 0) in struct {
  vec3 pos;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  o_color = texture(samplerCube(cube, samp), dto.pos);
}
