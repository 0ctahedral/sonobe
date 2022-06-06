#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec4 o_color;


layout (set = 1, binding = 0) uniform shader_uniform_object {
  vec3 albedo;
};

layout (set = 1, binding = 1) uniform sampler2D diffuse_sampler;

layout(location = 0) in vec3 output_mode;

layout(location = 1) in struct {
  vec2 tex_coord;
} in_dto;

void main() {
    // o_color = vec4(albedo, 1.0) * texture(diffuse_sampler, in_dto.tex_coord);
    o_color = texture(diffuse_sampler, in_dto.tex_coord);
}
