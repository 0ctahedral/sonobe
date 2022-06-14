[[vk::binding(2)]] 
Texture2D tex;

[[vk::binding(3)]] 
SamplerState samp;

struct VSOutput {
[[vk::location(0)]] float2 texcoord : TEXCOORD0;
};


float4 main(VSOutput input) : SV_TARGET {
  // return tex.Sample(samp, input.texcoord);
  return float4(0.0, 1.0, 0.0, 1.0);
}
