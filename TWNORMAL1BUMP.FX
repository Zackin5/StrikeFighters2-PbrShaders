//--------------------------------------------------------------------------------------
// File: twNormal1Bump.fx
// Copyright (c) 2009 Third Wire Productions, Inc.
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
    float3		g_CameraPos;
	int			g_bBumpEnabled;
	int			g_bInReflection;
};

cbuffer cbPerMaterial
{
 	int			g_bClampTexture;
	int			g_bFogEnabled;
 	int			g_bLightEnabled;
	float		g_SpecularPower;
  	float3		g_SpecularColor;	// specular level * dir light specular color * mat specular color
  	float		g_BumpAmount;
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
Texture2D g_BumpNormalTexture;

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

SamplerState g_BumpWrapSampler
{
    Filter = MIN_MAG_LINEAR_MIP_POINT;
    AddressU = Wrap;
    AddressV = Wrap;
};

SamplerState g_BumpClampSampler
{
    Filter = MIN_MAG_LINEAR_MIP_POINT;
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
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
	float2	uv			: TEXCOORD;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
	float2	uv			: TEXCOORD;
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

	const float3 N = mul(input.norm, (float3x3)g_mMeshToWorld);		// normal, world-space	
	output.pos_w.xyz = P.xyz;
	output.norm_w = N;
	
	output.uv = input.uv;
	
	if (g_bFogEnabled)
	{
		const float4 Pv = mul(P, g_mWorldToView);	// position in view-space
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
	const float metallic = TWNORMAL_METALLIC;
	const float roughness = TWNORMAL_ROUGHNESS;
	
	float4 output;

	if (g_bInReflection)
	{
		clip(input.pos_w.z + g_CameraPos.z);
	}

	if (!g_bFogEnabled || (input.pos_w.w < g_FogDistance.y))
	{
		float4 albedo;
		float3 Np;

		if (!g_bClampTexture)
		{
			albedo = g_MaterialTexture.Sample(g_TextureWrapSampler, input.uv);
			Np = g_BumpNormalTexture.Sample(g_BumpWrapSampler, input.uv).xyz * 2.0 - 1.0;
		}
		else
		{
			albedo = g_MaterialTexture.Sample(g_TextureClampSampler, input.uv);
			Np = g_BumpNormalTexture.Sample(g_BumpClampSampler, input.uv).xyz * 2.0 - 1.0;
		}

		// Calculate texture normals	
		float3 normal = CalculateBumpNormal(input.norm_w, input.pos_w.xyz, input.uv, Np, g_BumpAmount);

		// Calculate PBR
		output = Pbr(input, input.norm_w, albedo, metallic, roughness);
		// output = float4(irrad, 1);
		// output = Pbr(input, input.norm_w, float4(irrad, 1), float4(irrad, 1), float4(irrad, 1), metallic, roughness);
		
		if (g_bFogEnabled)
		{
			output.rgb = add_fog(output.rgb, input.pos_w.w, input.pos_w.z);
		}
	}
	else
	{
		output = float4(g_FogColor, 1.0);
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
// File: twNormal1Bump.fx
//--------------------------------------------------------------------------------------
    
