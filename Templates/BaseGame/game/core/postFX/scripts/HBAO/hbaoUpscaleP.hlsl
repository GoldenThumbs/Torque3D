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

TORQUE_UNIFORM_SAMPLER2D(deferredMap, 0);
TORQUE_UNIFORM_SAMPLER2D(aoMap, 1);
TORQUE_UNIFORM_SAMPLER2D(aoLerpTex, 2);
TORQUE_UNIFORM_SAMPLER2D(infoTex, 3);
uniform float2 nearFar;
uniform float2 targetSize;
uniform float2 oneOverTargetSize;

float4 main( PFXVertToPix IN ) : TORQUE_TARGET0
{
   float4 deferred = TORQUE_DEFERRED_UNCONDITION(deferredMap, IN.uv0).a;
   float depth = deferred.a * (nearFar.y - nearFar.x);
   float3 normal = deferred.xyz;

   float ao[4];
   ao[0] = TORQUE_TEX2D(aoMap, IN.uv1).r;
   ao[1] = TORQUE_TEX2D(aoMap, IN.uv1 + float2(0.0, 0.5) * oneOverTargetSize).r;
   ao[2] = TORQUE_TEX2D(aoMap, IN.uv1 + float2(0.5, 0.5) * oneOverTargetSize).r;
   ao[3] = TORQUE_TEX2D(aoMap, IN.uv1 + float2(0.5, 0.0) * oneOverTargetSize).r;

   float4 aoDeferred[4];
   aoDeferred[0] = TORQUE_TEX2D(infoTex, IN.uv3);
   aoDeferred[1] = TORQUE_TEX2D(infoTex, IN.uv3 + float2(0.0, 0.5) * oneOverTargetSize);
   aoDeferred[2] = TORQUE_TEX2D(infoTex, IN.uv3 + float2(0.5, 0.5) * oneOverTargetSize);
   aoDeferred[3] = TORQUE_TEX2D(infoTex, IN.uv3 + float2(0.5, 0.0) * oneOverTargetSize);

   float aoNDist[3];
   aoNDist[0] = dot(aoDeferred[0].xyz * 2.0f - 1.0f, aoDeferred[1].xyz * 2.0f - 1.0f);
   aoNDist[1] = dot(aoDeferred[0].xyz * 2.0f - 1.0f, aoDeferred[2].xyz * 2.0f - 1.0f);
   aoNDist[2] = dot(aoDeferred[0].xyz * 2.0f - 1.0f, aoDeferred[3].xyz * 2.0f - 1.0f);

   float minNDist = min(min(aoNDist[0], aoNDist[1]), aoNDist[2]);
   float nStep = step(0.997f, minNDist);

   float2 aoDDist[4];
   aoDDist[0] = float2(abs(depth - aoDeferred[0].a * (nearFar.y - nearFar.x)), ao[0]);
   aoDDist[1] = float2(abs(depth - aoDeferred[1].a * (nearFar.y - nearFar.x)), ao[1]);
   aoDDist[2] = float2(abs(depth - aoDeferred[2].a * (nearFar.y - nearFar.x)), ao[2]);
   aoDDist[3] = float2(abs(depth - aoDeferred[3].a * (nearFar.y - nearFar.x)), ao[3]);

   float2 minDist = float2(1.0f, 0.0f);
   [unroll]
   for (int i=0; i<4; i++)
   {
      if (minDist.x > aoDDist[i].x)
         minDist = aoDDist[i];
   }

   float aoLerp = TORQUE_TEX2D(aoLerpTex, IN.uv2).r;

   return lerp(minDist.y, aoLerp, nStep);
}
