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

#define MIP_OFFSET_BASE 4.3
#define KERNEL_SAMPLES 32
static const float4 KERNEL[32] = {
   float4(0.054409f, 0.000000f, 0.869477f, -0.201781f),
   float4(-0.086568f, 0.079298f, 0.731834f, -0.450411f),
   float4(0.014688f, -0.167218f, 0.631667f, -0.662764f),
   float4(0.129240f, 0.168609f, 0.550433f, -0.861360f),
   float4(-0.249426f, -0.044158f, 0.481790f, -1.053523f),
   float4(0.245989f, -0.156415f, 0.422512f, -1.242936f),
   float4(-0.085134f, 0.316415f, 0.370646f, -1.431887f),
   float4(-0.166854f, -0.321469f, 0.324882f, -1.622010f),
   float4(0.371326f, 0.135732f, 0.284282f, -1.814605f),
   float4(-0.395089f, 0.162934f, 0.248136f, -2.010797f),
   float4(0.194436f, -0.415101f, 0.215890f, -2.211631f),
   float4(0.146018f, 0.466189f, 0.187098f, -2.418135f),
   float4(-0.447964f, -0.259868f, 0.161391f, -2.631365f),
   float4(0.533857f, -0.117099f, 0.138461f, -2.852449f),
   float4(-0.330701f, 0.469874f, 0.118042f, -3.082624f),
   float4(-0.077040f, -0.597093f, 0.099906f, -3.323285f),
   float4(0.480707f, 0.405624f, 0.083851f, -3.576035f),
   float4(-0.654880f, 0.026671f, 0.069697f, -3.842754f),
   float4(0.483329f, -0.480341f, 0.057285f, -4.125687f),
   float4(-0.033151f, 0.706222f, 0.046470f, -4.427565f),
   float4(-0.468706f, -0.562507f, 0.037117f, -4.751771f),
   float4(0.750172f, 0.101524f, 0.029105f, -5.102586f),
   float4(-0.641852f, 0.445814f, 0.022319f, -5.485553f),
   float4(0.177488f, -0.785849f, 0.016653f, -5.908043f),
   float4(0.411771f, 0.720068f, 0.012005f, -6.380184f),
   float4(-0.812453f, -0.260018f, 0.008278f, -6.916442f),
   float4(0.795875f, -0.366791f, 0.005379f, -7.538549f),
   float4(-0.348027f, 0.829280f, 0.003214f, -8.281390f),
   float4(-0.311199f, -0.868019f, 0.001693f, -9.206408f),
   float4(0.835724f, 0.440371f, 0.000721f, -10.438111f),
   float4(-0.935285f, 0.245435f, 0.000199f, -12.298230f),
   float4(0.535856f, -0.831295f, 0.000013f, -16.277932f)
};

TORQUE_UNIFORM_SAMPLER2D(inputTex, 0);
uniform float aoRange;
uniform float aoStrength;
uniform float aoBias;

uniform float2 nearFar;
uniform float2 targetSize;
uniform float2 oneOverTargetSize;

float tapOcclusion(float2 uv, float range, float3 p, float3 n, float weightMod, float lvl, float bias, float4 NDCtoVSC, inout float weight)
{
   float sampleDepth = TORQUE_TEX2DLOD( inputTex, float4(uv, 0, lvl) ).a * (nearFar.y - nearFar.x);
   float3 v = getVSPosition(sampleDepth, uv, NDCtoVSC) - p;
   float w = 1.0f;
   float reduct = max(0.0f, v.z);
   reduct = saturate(2.0 - reduct / range);
   w = reduct;
   w *= weightMod;
   float rcpLen = rsqrt(dot(v, v));
   float d = dot(n, v) * rcpLen;
   float f = smoothstep(0.0, 1.0, range * rcpLen * 0.5f);
   weight += w;
   return saturate((d - bias) * w) * f;
}

float4 main(HBAOVertToPix IN) : TORQUE_TARGET0
{
   float2 fragPos = trunc(IN.uv0 * targetSize);
   float2 uv = fragPos * oneOverTargetSize + oneOverTargetSize * 0.25f;
    
   float4 deferred = TORQUE_TEX2DLOD( inputTex, float4(uv, 0, 0) );

   float depth = deferred.a * (nearFar.y - nearFar.x);
   float3 p = getVSPosition(depth, uv, IN.NDCtoVSC);
   float3 normal = normalize(deferred.xzy - 0.5f);
   normal.z = -normal.z;

   if (deferred.a > 0.999f)
      return float4(0.0, normal.xy * 0.5f + 0.5f, deferred.a);

   float ign = fmod(52.9829189f * fmod(0.06711056f*fragPos.x + 0.00583715f*fragPos.y, 1.0f), 1.0f) * M_2PI_F;

   float2 pixDir = p.z * IN.NDCtoVSC.xy * oneOverTargetSize;
   float aoScale = max(0.05f, (0.85f * aoRange) / pixDir.x);

   const float globalMipOffset = MIP_OFFSET_BASE;
   float mipOffset = log2(aoScale) + globalMipOffset;

   float screenBorder = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
   screenBorder = saturate(screenBorder * 10.0f + 0.6f);
   aoScale *= screenBorder;

   float2x2 noise = float2x2(
      cos(ign) * aoScale,-sin(ign) * aoScale,
      sin(ign) * aoScale, cos(ign) * aoScale);

   p *= 0.9992f;

   float occlusion = 0.0f;
   float weight = 0.0f;

   [unroll]
   for (int i=0; i<KERNEL_SAMPLES; i++)
   {
      float4 k = KERNEL[i];

      float2 offset = mul(noise, k.xy);
      offset = round(offset);

      float ao = tapOcclusion(offset * oneOverTargetSize + uv, aoRange, p, normal, k.z, k.w + mipOffset, aoBias, IN.NDCtoVSC, weight);
      occlusion += ao;
   }
   occlusion = saturate(occlusion / max(0.001f, weight) * aoStrength);

   return float4(occlusion, normal.xy * 0.5f + 0.5f, deferred.a);
}
