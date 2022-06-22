#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (set = 0, binding = 2) uniform texture2D textures[];
layout (set = 0, binding = 3) uniform sampler samplers[];

// idk if i like this
#define get_tex() textures[0]



layout(location = 0) in struct {
  vec2 tex_coord;
} _input;



layout(location = 0) out vec4 o_color;
struct Output {
  vec4 color;
};

void main() {

  Output fs_out;

  // imports:
  // samper: smapler
  // texure: texture2d
  // output from vs which is implicit
  // exports:
  // color: vec4
  // actual code
  /// texture2D tex = get_texture();
  fs_out.color = texture(sampler2D(get_tex(), samplers[0]), _input.tex_coord);
  // -----------




  o_color = fs_out.color;
}
