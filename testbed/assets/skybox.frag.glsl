#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (set = 0, binding = 1) uniform textureCube tex;
layout (set = 0, binding = 2) uniform sampler samp;

layout(location = 0) in struct {
  vec3 uvw;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  o_color = texture(samplerCube(tex, samp), dto.uvw);
}
