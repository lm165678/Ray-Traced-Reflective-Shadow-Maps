#include "Common.hlsli"
#include "hlslUtils.hlsli"
#include "ToneMapping.hlsli"


RaytracingAccelerationStructure gRtScene : register(t0);
RWTexture2D<float4> gOutput : register(u0);

cbuffer Camera : register(b0)
{
    float3 cameraPosition;
    float cameraYAngle;
    int frameCount;
}

float3 linearToSrgb(float3 c)
{
    // Based on http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
    float3 sq1 = sqrt(c);
    float3 sq2 = sqrt(sq1);
    float3 sq3 = sqrt(sq2);
    float3 srgb = 0.662002687 * sq1 + 0.684122060 * sq2 - 0.323583601 * sq3 - 0.0225411470 * c;
    return srgb;
}


[shader("raygeneration")]
void rayGen()
{
    uint3 launchIndex = DispatchRaysIndex();
    uint3 launchDim = DispatchRaysDimensions();

    float2 crd = float2(launchIndex.xy);
    float2 dims = float2(launchDim.xy);

    float2 d = ((crd / dims) * 2.f - 1.f);
    float aspectRatio = dims.x / dims.y;

    float3x3 yRotMat = float3x3(cos(cameraYAngle), 0, sin(cameraYAngle), 0, 1, 0, -sin(cameraYAngle), 0, cos(cameraYAngle));
    
    RayDesc ray;
    ray.Origin = cameraPosition.xyz;
    ray.Direction = normalize(mul(float3(d.x * aspectRatio, -d.y, 1), yRotMat));

    ray.TMin = 0;
    ray.TMax = 100000;

    uint randSeed = initRand(launchIndex.x + launchIndex.y * launchDim.x, frameCount, 16);
            
    RayPayload payload;
    float3 color = float3(0.0, 0.0, 0.0);

    int numSamples = 80;
    for (int i = 0; i < numSamples; i++)
    {
        nextRand(randSeed);

        payload.depth = 2;
        payload.seed = randSeed;
        TraceRay(
					gRtScene,
					0 /*rayFlags*/, 
					0xFF /*ray mask*/, 
					0 /* ray index*/, 
					1 /* total nbr of hit groups*/, 
					0 /* miss shader index*/, 
					ray, 
					payload
				);
        color += payload.color;
    }
    color /= numSamples;

    //color = linearToSrgb(color);

	//color = linearToSrgb(FilmicToneMapping(color));

    color = linearToSrgb(ACESFitted(1.5 * color));

    gOutput[launchIndex.xy] = float4((color), 1);
}

