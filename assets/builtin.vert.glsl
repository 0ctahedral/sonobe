#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec3 a_pos;

layout (set = 0, binding = 0) uniform global_uniform_object {
  mat4 projection;
  mat4 view;
  mat4 model;
} global_ubo;

void main() {
    //gl_Position = global_ubo.projection * global_ubo.view * vec4(a_pos, 1.0);    
    gl_Position = global_ubo.projection * global_ubo.view * global_ubo.model * vec4(a_pos, 1.0);    
}
