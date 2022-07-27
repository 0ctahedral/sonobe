#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (set = 1, binding = 1) uniform texture2D tex;
layout (set = 1, binding = 2) uniform sampler samp;
// material data
layout (set = 1, binding = 0) uniform readonly material_data {
  vec4 albedo;
  vec2 tiling;
};

layout(location = 0) in struct {
  vec2 uv;
} dto;

layout(location = 0) out vec4 o_color;

void main() {
  o_color = texture(sampler2D(tex, samp), dto.uv * tiling) * albedo;
}
