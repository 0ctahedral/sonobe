struct Input {
[[vk::location(0)]] float3 position;
[[vk::location(1)]] float2 texcoord;
};

struct Output {
  float4 position : SV_POSITION;
  [[vk::location(0)]] float2 texcoord : TEXCOORD0;
};


struct UBO {
  float4x4 projection;
  float4x4 view;
};


[[vk::binding(0, 0)]] 
UBO ubo;

// cbuffer UBO { UBO ubo; };


[[vk::push_constant]]
struct Consts {
	uint id;
  matrix model;
} consts;

Output main(Input input) {
  Output output = (Output)0;

  output.texcoord = input.texcoord;

  output.position = mul(ubo.projection, mul(ubo.view, mul(consts.model, float4(input.position, 1.0))));
  // output.position = mul(consts.model, float4(input.position, 1.0));

  return output;
}
