#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec4 o_color;

layout (set = 0, binding = 2) uniform texture2D tex;
layout (set = 0, binding = 3) uniform sampler samp;

// layout(location = 0) in vec3 output_mode;

layout(location = 1) in struct {
  vec2 tex_coord;
} in_dto;

void main() {
    o_color = texture(sampler2D(tex, samp), in_dto.tex_coord);
}
