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

#define MARCHING_STEPS 4
#define KERNEL_SAMPLES 16
static const float3 KERNEL[16] = {
   float3(0.176777, 0.000000, 0.135199),
   float3(-0.225780, 0.206818, 0.124385),
   float3(0.034587, -0.393769, 0.113756),
   float3(0.284530, 0.371204, 0.103322),
   float3(-0.522210, -0.092451, 0.093096),
   float3(0.494753, -0.314594, 0.083089),
   float3(-0.165602, 0.615488, 0.073318),
   float3(-0.315405, -0.607676, 0.063802),
   float3(0.684569, 0.250232, 0.054561),
   float3(-0.712353, 0.293773, 0.045625),
   float3(0.343624, -0.733602, 0.037026),
   float3(0.253403, 0.809035, 0.028812),
   float3(-0.764550, -0.443523, 0.021045),
   float3(0.897228, -0.196804, 0.013819),
   float3(-0.547908, 0.778490, 0.007297),
   float3(-0.125948, -0.976159, 0.001848)
};

TORQUE_UNIFORM_SAMPLER2D(inputTex, 0);
uniform float offsetAngle;
uniform float2 nearFar;
uniform float targetRatio;
uniform float2 oneOverTargetSize;

float3 getVSPosition(float depth, float2 uv, float4 NDCtoVSC)
{
   return float3(-depth * (uv * NDCtoVSC.xy + NDCtoVSC.zw), -depth);
}

float4 main(HBAOVertToPix IN) : TORQUE_TARGET0
{
   const float aoRange = 16.0f;
   const float rcpSteps = 1.0 / MARCHING_STEPS;
   float clipping = nearFar.y - nearFar.x;
    
   float4 deferred = TORQUE_TEX2D( inputTex, IN.uv0 );

   float3 normal = deferred.xyz;
   normal.y *= -1;
   normal = normal.xzy;

   float depth = deferred.a;
   float3 position = getVSPosition(depth * clipping, IN.uv0, IN.NDCtoVSC);
    
   if (depth > 0.999999f)
      return float4(0.0f, 0.0f, 0.0f, 1.0f);
   
   float2x2 rotMat = float2x2(
      cos(offsetAngle * 0.01745329251f),-sin(offsetAngle * 0.01745329251f),
      sin(offsetAngle * 0.01745329251f), cos(offsetAngle * 0.01745329251f));
    
   float rangeRad = aoRange / position.z;
   float rangeStep = rangeRad / MARCHING_STEPS;

   float occlusion = 0.0f;

   [unroll]
   for (int i=0; i<KERNEL_SAMPLES; i++)
   {
      float3 offsetWeight = KERNEL[i];
      float2 offset = mul(rotMat, offsetWeight.xy);
      offset.x *= targetRatio;
      float weight = offsetWeight.z;
      
      float topOcc = 0.0f;
      [unroll]
      for (int j=0; j<MARCHING_STEPS; j++)
      {
         float2 stepOffset = float(j+1) * rangeStep * offset * oneOverTargetSize;
         
         float sampleD = TORQUE_TEX2D( inputTex, IN.uv0 + stepOffset ).a;
         float3 sampleP = getVSPosition(sampleD * clipping, IN.uv0 + stepOffset, IN.NDCtoVSC);
         float3 V = sampleP - position;

         float VdV = dot(V, V);
         float NdV = M_HALFPI_F - acos(dot(normal, V) * rsqrt(VdV));

         topOcc += max(0.0f, sin(NdV));
      }

      occlusion += topOcc * weight;
   }
    occlusion *= rcpSteps;
    occlusion = 1.0 - occlusion;

   return float4(occlusion, occlusion, occlusion, 1.0f);
}
