struct Input {
[[vk::location(0)]] float3 position : POSITION0;
[[vk::location(1)]] float2 texcoord : TEXCOORD0;
};

struct UBO {
  matrix projection;
  matrix view;
};

[[vk::binding(0)]] 
cbuffer ubo : register(b0) { UBO ubo; };

[[vk::push_constant]]
cbuffer {
  uint id;
  matrix model;
};

struct Output {
  float4 position : SV_POSITION;
  [[vk::location(0)]] float2 texcoord : TEXCOORD0;
};



Output main(Input input) {
  Output output = (Output)0;

  output.texcoord = input.texcoord;
  output.position = mul(ubo.projection, mul(ubo.view, mul(model, float4(input.position, 1.0))));
  // output.position = mul(ubo.projection, mul(ubo.view, float4(input.position, 1.0)));

  return output;
}
