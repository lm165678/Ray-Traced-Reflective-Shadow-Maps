#include "Common.hlsli"
#include "hlslUtils.hlsli"


RaytracingAccelerationStructure gRtScene : register(t0);
RWTexture2D<float4> gOutput : register(u0);

cbuffer Camera : register(b0)
{
    float3 cameraPosition;
    float4 cameraDirection;
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

    float yRotAngle = cameraDirection.w;
    float3x3 yRotMat = float3x3(cos(yRotAngle), 0, sin(yRotAngle), 0, 1, 0, -sin(yRotAngle), 0, cos(yRotAngle));
    
    RayDesc rayOG;
    rayOG.Origin = cameraPosition; // float3(0, 0, -2);//;
    rayOG.Direction = normalize(mul(float3(d.x * aspectRatio, -d.y, 1), yRotMat));

    rayOG.TMin = 0;
    rayOG.TMax = 100000;

    RayPayload payloadOG;
    TraceRay(gRtScene, 0 /*rayFlags*/, 0xFF, 0 /* ray index*/, 2, 0, rayOG, payloadOG);
    float3 color = payloadOG.colorAndDistance.rgb;

    if (payloadOG.colorAndDistance.w > 0) // it's a hit!
    {
	// Fire a second ray. The direction is hard-coded here, but can be fetched from a constant-buffer
 
        uint gFrameCount = 37;// TODO: CHANGE!!!
        uint randSeed = initRand(launchIndex.x + launchIndex.y * launchDim.x, gFrameCount, 16);
		RayPayload payloadDiffuse;
        RayDesc rayDiffuse;
        float3 colorsum = float3(0.0, 0.0, 0.0);
        
        for (int i = 0; i < 256; i++)
        {
            rayDiffuse.Origin = rayOG.Origin + rayOG.Direction * payloadOG.colorAndDistance.w;
            rayDiffuse.Direction = getCosHemisphereSample(randSeed, payloadOG.normal);

            rayDiffuse.TMin = 0.01; // watch out for this value
            rayDiffuse.TMax = 100000;

            TraceRay(gRtScene, 0 /*rayFlags*/, 0xFF, 0 /* ray index*/, 2, 0, rayDiffuse, payloadDiffuse);
            if (payloadDiffuse.colorAndDistance.w > 0) // did not hit sky (i.e. hit an object)
            {
                colorsum += float3(0.0, 0.0, 0.0); //unneccessairy
            }
            else // did hit sky
            {
                colorsum += payloadDiffuse.colorAndDistance.rgb;
            }

        }
        color *= colorsum/256;

  //      RayDesc shadowRay;
  //      shadowRay.Origin = ray.Origin + ray.Direction * payload.colorAndDistance.w;
  //      shadowRay.Direction = lightDir;
  //      shadowRay.TMin = 0.2;// watch out for this value
  //      shadowRay.TMax = 100000;
  //      ShadowPayload shadowPayload;
  //      TraceRay(gRtScene, 0 /*rayFlags*/, 0xFF, 1 /* ray index*/, 0, 1, shadowRay, shadowPayload);

		//float directShadowFactor = shadowPayload.hit ? 0.0 : 1.0;
  //      col = col * directShadowFactor;
        }

		color = linearToSrgb(color);
        gOutput[launchIndex.xy] = float4(color, 1);
    }
