//-----------------------------------------------------------------------------
// Copyright (c) 2012 GarageGames, LLC
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//-----------------------------------------------------------------------------

#include "./hbaoInc.hlsl"

#define MARCHING_SAMPLES 4
#define KERNEL_SAMPLES 16
static const float4 KERNEL[16] = {
   float4(0.176777f, 0.000000f, 0.386483f, 0.307675f),
   float4(-0.225780f, 0.206818f, 0.032234f, 0.200634f),
   float4(0.034587f, -0.393769f, 0.261175f, 0.142290f),
   float4(0.284530f, 0.371204f, 0.151057f, 0.103437f),
   float4(-0.522210f, -0.092451f, 0.040588f, 0.075645f),
   float4(0.494753f, -0.314594f, 0.094695f, 0.055082f),
   float4(-0.165602f, 0.615488f, 0.047261f, 0.039622f),
   float4(-0.315405f, -0.607676f, 0.267006f, 0.027943f),
   float4(0.684569f, 0.250232f, 0.046437f, 0.019153f),
   float4(-0.712353f, 0.293773f, 0.224330f, 0.012619f),
   float4(0.343624f, -0.733602f, 0.072014f, 0.007864f),
   float4(0.253403f, 0.809035f, 0.106099f, 0.004523f),
   float4(-0.764550f, -0.443523f, 0.112595f, 0.002299f),
   float4(0.897228f, -0.196804f, 0.073468f, 0.000947f),
   float4(-0.547908f, 0.778490f, 0.023097f, 0.000253f),
   float4(-0.125948f, -0.976159f, 0.227789f, 0.000016f)
};

TORQUE_UNIFORM_SAMPLER2D(inputTex, 0);
uniform float2 nearFar;
uniform float2 targetSize;
uniform float targetRatio;

float3 getVSPosition(float depth, float2 uv, float4 NDCtoVSC)
{
   return float3(-depth * (uv * NDCtoVSC.xy + NDCtoVSC.zw), -depth);
}

float2 getUVFromVSPosition(float3 pos, float4 NDCtoVSC)
{
   return ((pos.xy / pos.z) - NDCtoVSC.zw) / NDCtoVSC.xy;
}

float tapOcclusion(float2 uv, float range, float3 p, float3 n, float4 NDCtoVSC)
{
   float sampleDepth = TORQUE_TEX2D( inputTex, uv ).a * (nearFar.y - nearFar.x);
   float3 v = getVSPosition(sampleDepth, uv, NDCtoVSC) - p;
   
   float rcpLen = rsqrt(dot(v, v));
   float d = dot(n, v) * rcpLen;
   float w = smoothstep(0.0f, 1.0f, range * rcpLen * 0.5f);
   return saturate(d - 0.25f) * w;
}

float4 main(HBAOVertToPix IN) : TORQUE_TARGET0
{
   const float rcpMarch = 1.0 / MARCHING_SAMPLES;
   const float aoRange = 0.5f;
    
   float4 deferred = TORQUE_TEX2D( inputTex, IN.uv0 );
   float depth = deferred.a * (nearFar.y - nearFar.x);

   if (depth > nearFar.y * 0.99f)
      return float4(1.0, 1.0, 1.0, 1.0);

   float3 p = getVSPosition(depth, IN.uv0, IN.NDCtoVSC);

   float3 normal = normalize(deferred.xzy - 0.5f);
   normal.z = -normal.z;

   float2 noiseMapUV = IN.uv0 * targetSize;
   float ign = fmod(52.9829189f * fmod(0.06711056f*noiseMapUV.x + 0.00583715f*noiseMapUV.y, 1.0f), 1.0f) * M_2PI_F;
    
   float2x2 noise = float2x2(
      cos(ign),-sin(ign),
      sin(ign), cos(ign));

   float aoScale = max(0.05f, aoRange / depth);

   float occlusion = 0.0f;

   [unroll]
   for (int i=0; i<KERNEL_SAMPLES; i++)
   {
      float4 k = KERNEL[i];

      float3 offset = k.xyz * aoScale;
      offset.y *= targetRatio;
      float3 offsetStep = offset * rcpMarch;
      
      float topAO = 0.0f;
      [unroll]
      for (int j=0; j<MARCHING_SAMPLES; j++)
      {
         float3 ray = offsetStep * float(j+1);
         float2 coords = mul(noise, ray.xy);

         float ao_1 = tapOcclusion(IN.uv0 + coords, aoRange, p, normal, IN.NDCtoVSC);
         float ao_2 = tapOcclusion(IN.uv0 - coords, aoRange, p, normal, IN.NDCtoVSC);
         topAO = lerp((ao_1 + ao_2) * 0.5f, 1.0f, topAO);
      }
      occlusion += topAO * k.w;
   }
   occlusion = 1.0 - occlusion;

   return float4(occlusion, occlusion, occlusion, 1.0f);
}
