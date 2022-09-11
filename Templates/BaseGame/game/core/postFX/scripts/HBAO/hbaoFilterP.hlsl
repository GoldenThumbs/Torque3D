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

#define KERNEL_SAMPLES 4
static const float2 KERNEL[4] = {
  float2( 0.5f, 0.5f),
  float2( 0.5f,-0.5f),
  float2(-0.5f,-0.5f),
  float2(-0.5f, 0.5f)
};

TORQUE_UNIFORM_SAMPLER2D(frameTex, 0);
TORQUE_UNIFORM_SAMPLER2D(prevFrameTex, 1);

uniform float deltaTime;
uniform float2 nearFar;
uniform float2 targetSize;
uniform float2 oneOverTargetSize;
uniform float3 eyePosWorld;
uniform float4x4 invCameraMat;
uniform float4x4 matPrevScreenToWorld;

float4 main( HBAOVertToPix IN ) : TORQUE_TARGET0
{
   float2 fragPos = trunc(IN.uv0 * targetSize) + 0.5;
   float2 uv = fragPos * oneOverTargetSize;

   float4 input = TORQUE_TEX2DLOD(frameTex, float4(uv, 0, 0));
   float ao = input.x;
   float depth = input.a * (nearFar.y - nearFar.x);
   float2 normal = input.yz * 2.0 - 1.0;

   if (input.a > 0.999f)
      return float4(0.0, 0.5, 0.5, 1.0);
   
   float3 posView = getVSPosition(depth, uv, IN.NDCtoVSC);

   float4 posWld = mul(float4(posView.x,-posView.z, posView.y, 0.0f), invCameraMat);
   posWld.xyz = eyePosWorld + posWld.xyz;
   float4 screen = mul(float4(posWld.xyz, 1), matPrevScreenToWorld);
   screen /= screen.w;
   float2 coords = screen.xy * 0.5 + 0.5;
   coords.y = 1.0 - coords.y;
    
   float4 inputP = TORQUE_TEX2DLOD(prevFrameTex, float4(coords, 0, 0));
   float aoP = inputP.x;
   float depthP = inputP.a * (nearFar.y - nearFar.x);
   float2 normalP = inputP.yz * 2.0 - 1.0;
   float3 posViewP = getVSPosition(depthP, coords, IN.NDCtoVSC);
    
   float weight = distance(posViewP, posView) * 9.0f;
   weight += abs(aoP - ao) * 5.0f;
   weight = saturate(max(deltaTime, weight));
    
   float occlusion = lerp(aoP, ao, weight);

   return float4(occlusion, input.yzw);
}
