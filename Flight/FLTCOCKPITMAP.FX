//--------------------------------------------------------------------------------------
// File: fltCockpitMap.fx
// Copyright (c) 2012 Third Wire Productions, Inc.
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
    float4x4	g_mViewProj;
	float3		g_AmbientLight;
	DirLight	g_DirLight;

	// Empty definitions for PBR.H compat
    float4x4	g_mWorldToView;
	float3		g_FogDistance;
    float3		g_FogColor;
    float3		g_FogLayer;
};

cbuffer cbPerMaterial
{
 	int			g_bClampTexture;
 	int			g_bSpecularEnabled;
	float		g_SpecularPower;
  	float3		g_SpecularColor;	// specular level * dir light specular color * mat specular color
};

cbuffer cbPerMesh
{
	float4x4	g_mMeshToWorld;
	int			g_NumPointLights;
	int			g_NumSpotLights;
    PointLight	g_aPointLights[8];
    SpotLight	g_aSpotLights[2];
};

Texture2D g_MaterialTexture;

SamplerState g_TextureWrapSampler
{
    Filter = ANISOTROPIC;
    AddressU = Wrap;
    AddressV = Wrap;
};

SamplerState g_TextureClampSampler
{
    Filter = ANISOTROPIC;
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
 	float3	pos_w		: COLOR0;				//xyz = world space pos
	float3	norm_w		: COLOR1;				//world space normal
	float2	uv			: TEXCOORD;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
 	float3	pos_w		: COLOR0;				//xyz = world space pos
	float3	norm_w		: COLOR1;				//world space normal
	float2	uv			: TEXCOORD;
};

#include "TWCOMMON.H"
#include "PBR.H"
#include "FX_COMMON.H"
#include "CONFIG_FX.H"
 
//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT VS( VS_INPUT input )
{    
    VS_OUTPUT output;
    
 	const float4 P = mul(float4(input.pos, 1.0), g_mMeshToWorld);	// position, world-space
	
	output.pos = compute_pos(P);
	
	const float3 N = mul(input.norm, (float3x3)g_mMeshToWorld);		// normal, world-space	
	output.pos_w = P.xyz;
	output.norm_w = N;
	
	output.uv = input.uv;	
	return output;    
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

float4 PS( PS_INPUT input ) : SV_TARGET
{
	const float metallic = TV_METALLIC;
	const float roughness = TV_ROUGHNESS;

	// Screen pass
	float4 screen;
	
	if (!g_bClampTexture)
	{
		screen = SampleChromaticAberration(g_MaterialTexture, g_TextureWrapSampler, input.uv, TV_CA_OFFSET, TV_CA_STRENGTH); 
	}
	else
	{
		screen = SampleChromaticAberration(g_MaterialTexture, g_TextureClampSampler, input.uv, TV_CA_OFFSET, TV_CA_STRENGTH); 
	}
	
	// Calculate PBR
	const float3 N = normalize(input.norm_w);
	float3 sunColor = g_DirLight.color * max(0, dot(N, -g_DirLight.dir));
	float4 pbr = Pbr(input, N, screen, float4(g_AmbientLight, 1), float4(sunColor, 1), metallic, roughness);	

	float4 diffuse = lerp(pbr, screen, 0.25);	// Backlight glow
	
	return diffuse;
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
// File: fltCockpitMap.fx
//--------------------------------------------------------------------------------------
    
