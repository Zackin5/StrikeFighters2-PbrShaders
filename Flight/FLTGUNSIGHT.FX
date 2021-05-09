//--------------------------------------------------------------------------------------
// File: fltGunsight.fx
// Copyright (c) 2011 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Constant Buffers
//--------------------------------------------------------------------------------------
  
cbuffer cbGlobal
{
    float4x4	g_mViewProj;
};

cbuffer cbPerMesh
{
	float4x4	g_mMeshToWorld;
};

Texture2D g_MaterialTexture;

SamplerState g_LinearSampler
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VS_INPUT
{
    float3 pos		: POSITION; 
    float4 diffuse	: COLOR;
	float2 uv		: TEXCOORD;
};

struct VS_OUTPUT
{
	float4 diffuse	: COLOR;
    float2 uv		: TEXCOORD;

    float4 pos		: SV_POSITION;
};

struct PS_INPUT
{
	float4 diffuse	: COLOR;
    float2 uv		: TEXCOORD;
};

#include "CONFIG_FX.H"

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT VS( VS_INPUT input )
{    
    VS_OUTPUT output;
   
	const float4 P = mul(float4(input.pos, 1.0), g_mMeshToWorld);	// position, world-space	
	
	output.pos = mul(P, g_mViewProj);		

	output.uv = input.uv;
	output.diffuse = input.diffuse;
	
    return output;    
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

float4 PS( PS_INPUT input ) : SV_TARGET
{
	float4 sightColor = g_MaterialTexture.Sample(g_LinearSampler, input.uv);

    float4 caColor = float4(0,0,0,0);
    caColor.r = g_MaterialTexture.Sample(g_LinearSampler, input.uv, +GUNSIGHT_CA).r;
    caColor.g = g_MaterialTexture.Sample(g_LinearSampler, input.uv).g;
    caColor.b = g_MaterialTexture.Sample(g_LinearSampler, input.uv, -GUNSIGHT_CA).b;

    caColor.a = (g_MaterialTexture.Sample(g_LinearSampler, input.uv, +GUNSIGHT_CA).a
                + g_MaterialTexture.Sample(g_LinearSampler, input.uv).a
                + g_MaterialTexture.Sample(g_LinearSampler, input.uv, -GUNSIGHT_CA).a) 
                / 3.0;

	float4 output = sightColor;

    if(GUNSIGHT_STRENGTH > 0)
        output = lerp(sightColor, caColor, GUNSIGHT_STRENGTH);

	output *= input.diffuse;
    output.a *= GUNSIGHT_ALPHA;
    
	return output;
}

//--------------------------------------------------------------------------------------
technique10 Render
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PS() ) );
    }
}

//--------------------------------------------------------------------------------------
// File: fltGunsight.fx
//--------------------------------------------------------------------------------------
