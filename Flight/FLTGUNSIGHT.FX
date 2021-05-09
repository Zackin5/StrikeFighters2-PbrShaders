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
	float4 output = g_MaterialTexture.Sample(g_LinearSampler, input.uv);
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
