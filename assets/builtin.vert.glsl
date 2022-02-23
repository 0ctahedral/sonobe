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
	uint model_idx;
};

// data from bound buffers
// here are constants for shader instances
// starting with the transformation matrix
//
struct ObjData {
  mat4 model;
};
layout (set = 0, binding = 1) buffer cbuf {
  ObjData objects[];
};


void main() {
    gl_Position = projection * view * objects[model_idx].model * vec4(a_pos, 1.0);    
}
