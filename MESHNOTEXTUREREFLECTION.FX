//--------------------------------------------------------------------------------------
// File: meshNoTexture.fx
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

cbuffer cbPerMaterial
{
	int			g_bFogEnabled;
 	int			g_bLightEnabled;
 	float3		g_DiffuseColor;
 	int			g_bSpecularEnabled;
	float		g_SpecularPower;
  	float3		g_SpecularColor;	// specular level * dir light specular color * mat specular color
};

cbuffer cbPerMesh
{
	float4x4	g_mMeshToWorld;
	int			g_NumPointLights;
    PointLight	g_aPointLights[8];
	int			g_NumSpotLights;
    SpotLight	g_aSpotLights[2];
};

Texture2D g_MaterialTexture;

SamplerState g_TextureWrapSampler
{
    Filter = ANISOTROPIC;
    AddressU = Wrap;
    AddressV = Wrap;
};

struct VS_INPUT
{
    float3	pos			: POSITION; 
    float3	norm		: NORMAL;
	float2	uv			: TEXCOORD;
};

struct VS_OUTPUT
{
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
    float2 	uv			: TEXCOORD;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
    float2 	uv			: TEXCOORD;
};

#include "TWCOMMON.H"

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT VS( VS_INPUT input )
{    
    VS_OUTPUT output;
   
	const float4 P = mul(float4(input.pos, 1.0), g_mMeshToWorld);	// position, world-space	
	
//	output.pos = mul(P, g_mViewProj);		
	output.pos = compute_pos(P);

	output.pos_w.xyz = P.xyz;
	
	// calculate spherical reflection coordidates
	const float3 N = mul(input.norm, (float3x3)g_mMeshToWorld);		// normal, world-space	
	const float3 Nv = mul(N, (float3x3)g_mWorldToView);				// normal, view-space
	output.norm_w = N;
	
	output.uv.x = 0.5 * Nv.x + 0.5;
	output.uv.y = -0.5 * Nv.y + 0.5;

	if (g_bFogEnabled)
	{
		const float4 Pv = mul(P, g_mWorldToView);						// position, view-space
		output.pos_w.w = Pv.z;
	}
	else
	{
		output.pos_w.w = 0.0f;
	}
    return output;    
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

#include "PBR.H"

float4 PS( PS_INPUT input ) : SV_TARGET
{
	// PBR irradiance map
	float4 irradiance = CalculateIrradianceMap(g_MaterialTexture, input.norm_w);

	float metallic = MESHREFLECTION_METALLIC;
	float roughness = MESHREFLECTION_ROUGHNESS;

	float4 output = float4(g_DiffuseColor, 1.0);
	
	if (!g_bFogEnabled || (input.pos_w.w < g_FogDistance.y))
	{
		// PBR IBF specular
		float4 specular = g_MaterialTexture.Sample(g_TextureWrapSampler, input.uv);
		specular = lerp(specular, irradiance, roughness);

		output = Pbr(input, input.norm_w, output, irradiance, specular, metallic, roughness);
		
		if (g_bFogEnabled)
		{
			output.rgb = add_fog(output.rgb, input.pos_w.w, input.pos_w.z);
		}		
	}
	else
	{
		output.rgb = g_FogColor;
	}
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
// File: meshNoTexture.fx
//--------------------------------------------------------------------------------------
    