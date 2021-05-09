//--------------------------------------------------------------------------------------
// File: terFarTerrainEffect.fx
// Copyright (c) 2008 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------

struct DirLight
{
    float3	dir;
    float	___d4;		//float3 aligned to 4
    float3	color;	
    float	___c4;		//float3 aligned to 4
};

struct PointLight
{
    float3	color;		
    float	Range2;		//float3 aligned to 4
    float3	pos;
    float	invRange;
};

struct SpotLight
{
    float3	color;		
    float	___c4;		//float3 aligned to 4
    float3	pos;		
	float	___p4;		//float3 aligned to 4
    float3	dir;		
    float	Range2;		//float3 aligned to 4
    float	invRange;
    float3	angles;		// x = cos(Theta/2) (inner angle), y = cos(Phi/2) (outer angle), z = 1/(x - y)
};

//--------------------------------------------------------------------------------------
// Constant Buffers
//--------------------------------------------------------------------------------------
  
cbuffer cbGlobal
{
    float4x4	g_mWorldToView;
    float4x4	g_mViewProj;
	float3		g_FogDistance;		// x = Start, y = End, z =  1 / (y - x)
    float3		g_FogColor;
    float3		g_FogLayer;			// x = amount, y = altitude (camera-relative), z = thickness
	float3		g_AmbientLight;
	DirLight	g_DirLight;
};

cbuffer cbPerMesh
{
	float3		g_MeshOffsetPos;
	int			g_NumPointLights;
    PointLight	g_aPointLights[8];
	int			g_NumSpotLights;
    SpotLight	g_aSpotLights[2];
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
    float3	pos			: POSITION; 
    float3	norm		: NORMAL;
	float2	uv			: TEXCOORD;
};

struct VS_OUTPUT
{
	float3 	diffuse		: COLOR0;
  	float4 	pos_w		: COLOR1;				//xyz = world space pos, w = fogdist
	float3 	norm_w		: COLOR2;				//world space normal
	float2 	uv			: TEXCOORD;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
	float3 	diffuse		: COLOR0;
  	float4 	pos_w		: COLOR1;				//xyz = world space pos, w = fogdist
	float3 	norm_w		: COLOR2;				//world space normal
	float2 	uv			: TEXCOORD;
};
	
#include "..\..\Flight\TWCOMMON.H"

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT VS( VS_INPUT input )
{
    VS_OUTPUT output;
    
	const float4 P = float4((input.pos + g_MeshOffsetPos), 1.0);	// position, world-space	
	const float4 Pv = mul(P, g_mWorldToView);	// position in view-space

	const float3 L = -g_DirLight.dir;
	const float3 N = input.norm;	

//	output.pos = mul(P, g_mViewProj);		
	output.pos = compute_pos(P);

 	output.diffuse = g_AmbientLight + g_DirLight.color * max(0, dot(N, L));
	output.pos_w.xyz = P.xyz;
	output.pos_w.w = Pv.z;
	output.norm_w = N;
	output.uv = input.uv;

    return output;    
 }

//--------------------------------------------------------------------------------------
// PixelShader
//--------------------------------------------------------------------------------------
#include "..\PBR.H"

float4 PS( PS_INPUT input ) : SV_TARGET
{ 
	const float metallic = TERRAIN_METALLIC;
	const float roughness = TERRAIN_ROUGHNESS;
	float3 output;
	
	if (input.pos_w.w < g_FogDistance.y)
	{
		float4 albedo = g_MaterialTexture.Sample(g_LinearSampler, input.uv); 
		
		output = Pbr(input, input.norm_w, albedo, metallic, roughness).rgb;
			
		output = add_fog(output, input.pos_w.w, input.pos_w.z);
	}
	else
	{
		output = g_FogColor;
	}
	return (float4(saturate(output), 1.0));
}

//--------------------------------------------------------------------------------------
// Techniques
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
// File: terFarTerrainEffect.fx
//--------------------------------------------------------------------------------------
    