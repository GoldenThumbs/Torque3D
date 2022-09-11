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

#include "core/rendering/shaders/shaderModelAutoGen.hlsl"
#include "core/rendering/shaders/postFX/postFx.hlsl"

#define BLUR_ITER 2

TORQUE_UNIFORM_SAMPLER2D(aoMap, 0);
TORQUE_UNIFORM_SAMPLER2D(infoTex, 1);
uniform float2 blurDir;

uniform float2 nearFar;
uniform float2 oneOverTargetSize;

float gaussWeight(float x, float mu, float sigma)
{
   float d = x - mu;
   return exp2(-d*d * rcp(2 * sigma*sigma));
}

float gaussBlur(float2 uv, float2 offset, float r, float depth, inout float weight)
{
   float4 input = TORQUE_TEX2DLOD(infoTex, float4(uv + offset, 0, 0));
   float ao = TORQUE_TEX2DLOD(aoMap, float4(uv + offset, 0, 0)).r;
   float z = input.a * (nearFar.y - nearFar.x);

   float diff = abs(z - depth) * 40.0f;

   const float sigma = BLUR_ITER * 0.5f;
   float w = gaussWeight(r, diff, sigma);

   weight += w;
   return ao * w;
}

float4 main( PFXVertToPix IN ) : TORQUE_TARGET0
{
   float4 input = TORQUE_TEX2DLOD(infoTex, float4(IN.uv0, 0, 0));
   float ao = TORQUE_TEX2DLOD(aoMap, float4(IN.uv0, 0, 0)).r;
   float z = input.a * (nearFar.y - nearFar.x);
   float weight = 1.0f;

   for (int i=1; i<=BLUR_ITER; i++)
   {
      float2 offset = oneOverTargetSize * float(i) * blurDir;
      ao += gaussBlur(IN.uv0, offset, float(i), z, weight);
   }

   for (int j=1; j<=BLUR_ITER; j++)
   {
      float2 offset = oneOverTargetSize * -float(j) * blurDir;
      ao += gaussBlur(IN.uv0, offset, float(j), z, weight);
   }

   ao /= weight;

   return float4(ao, input.yzw);
}
