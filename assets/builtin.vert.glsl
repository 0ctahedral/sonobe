#version 450
#extension GL_ARB_separate_shader_objects : enable

// vertex data
layout(location = 0) in vec3 a_pos;

layout (set = 0, binding = 0) uniform global_uniform_object {
  mat4 projection;
  mat4 view;
};

layout( push_constant ) uniform PushConstants
{
	uint id;
  mat4 model;
};

void main() {
    gl_Position = projection * view * model * vec4(a_pos, 1.0);    
}
