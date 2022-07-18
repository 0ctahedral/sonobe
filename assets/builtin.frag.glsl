#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (set = 0, binding = 2) uniform texture2D tex;
layout (set = 0, binding = 3) uniform sampler samp;

// TODO
// layout (set = 1, binding = 2) uniform texture2D tex;
// layout (set = 1, binding = 3) uniform sampler samp;

layout(location = 0) in struct {
  vec2 tex_coord;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  o_color = texture(sampler2D(tex, samp), dto.tex_coord);
}
