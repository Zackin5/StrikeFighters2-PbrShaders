//--------------------------------------------------------------------------------------
// File: meshDecal4Bump.fx
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
};

cbuffer cbPerMaterial
{
 	int			g_bClampTexture;
	int			g_bFogEnabled;
 	int			g_bLightEnabled;
 	int			g_bSpecularEnabled;
	float		g_SpecularLevel;
	float		g_SpecularPower;
  	float3		g_SpecularColor;	// specular level * dir light specular color * mat specular color
  	float		g_BumpAmount;
};

cbuffer cbPerMesh
{
	float4x4	g_mMeshToWorld;
	int			g_NumPointLights;
    PointLight	g_aPointLights[8];
	int			g_NumSpotLights;
    SpotLight	g_aSpotLights[2];
};

Texture2D g_MaterialTexture0;
Texture2D g_BumpNormalTexture;
Texture2D g_MaterialTexture2;
Texture2D g_MaterialTexture3;
Texture2D g_MaterialTexture4;
Texture2D g_MaterialTexture5;

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
	float2	uv0			: TEXCOORD0;
	float2	uv1			: TEXCOORD1;
	float2	uv2			: TEXCOORD2;
	float2	uv3			: TEXCOORD3;
	float2	uv4			: TEXCOORD4;
	float2	uv5			: TEXCOORD5;
	float2	uv6			: TEXCOORD6;
	float2	uv7			: TEXCOORD7;
};

struct VS_OUTPUT
{
 	float4	pos_w		: COLOR0;			//xyz = world space pos, w = fogdist
	float3 	norm_w		: COLOR1;			//xyz = world space normal
    float2 	uv0			: TEXCOORD0;
	float2 	uv2			: TEXCOORD1;
	float2 	uv3			: TEXCOORD2;
	float2 	uv4			: TEXCOORD3;
	float2 	uv5			: TEXCOORD4;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
 	float4	pos_w		: COLOR0;			//xyz = world space pos, w = fogdist
	float3 	norm_w		: COLOR1;			//xyz = world space normal
    float2 	uv0			: TEXCOORD0;
	float2 	uv2			: TEXCOORD1;
	float2 	uv3			: TEXCOORD2;
	float2 	uv4			: TEXCOORD3;
	float2 	uv5			: TEXCOORD4;
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
	output.norm_w = mul(input.norm, (float3x3)g_mMeshToWorld);		// normal, world-space	
				
	output.uv0 = input.uv0;
	output.uv2 = input.uv2;
	output.uv3 = input.uv3;
	output.uv4 = input.uv4;
	output.uv5 = input.uv5;
	
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
	const float mMetallic = TWNORMAL_SPECULAR;
	const float mRoughness = TWNORMAL_ROUGHNESS;

	const float dMetallic = MESHDECAL_SPECULAR;
	const float dRoughness = MESHDECAL_ROUGHNESS;
		
	float4 output;
	
	if (!g_bFogEnabled || (input.pos_w.w < g_FogDistance.y))
	{
		float4 albedo;
		float3 Np;

		if (!g_bClampTexture)
		{
			albedo = g_MaterialTexture0.Sample(g_TextureWrapSampler, input.uv0);
			Np = g_BumpNormalTexture.Sample(g_BumpWrapSampler, input.uv0).xyz * 2.0 - 1.0;
		}
		else
		{
			albedo = g_MaterialTexture0.Sample(g_TextureClampSampler, input.uv0);
			Np = g_BumpNormalTexture.Sample(g_BumpClampSampler, input.uv0).xyz * 2.0 - 1.0;
		}
		 		
		if (albedo.a > 0.0)
		{ 	
			// Calculate texture normals		
			float3 normal = CalculateBumpNormal(input.norm_w, input.pos_w.xyz, input.uv0, Np, g_BumpAmount);

			float4 decal = g_MaterialTexture2.Sample(g_TextureClampSampler, input.uv2);

			// Calculate alpha between decal and surface
			albedo = lerp(albedo, decal, decal.a);
			float metallic = lerp(mMetallic, dMetallic, decal.a);
			float roughness = lerp(mRoughness, dRoughness, decal.a);

			decal = g_MaterialTexture3.Sample(g_TextureClampSampler, input.uv3);

			// Calculate alpha between decal and surface
			albedo = lerp(albedo, decal, decal.a);
			metallic = lerp(metallic, dMetallic, decal.a);
			roughness = lerp(roughness, dRoughness, decal.a);

			decal = g_MaterialTexture4.Sample(g_TextureClampSampler, input.uv4);

			// Calculate alpha between decal and surface
			albedo = lerp(albedo, decal, decal.a);
			metallic = lerp(metallic, dMetallic, decal.a);
			roughness = lerp(roughness, dRoughness, decal.a);

			decal = g_MaterialTexture5.Sample(g_TextureClampSampler, input.uv5);

			// Calculate alpha between decal and surface
			albedo = lerp(albedo, decal, decal.a);
			metallic = lerp(metallic, dMetallic, decal.a);
			roughness = lerp(roughness, dRoughness, decal.a);

			// Calculate PBR
			output = Pbr(input, normal, albedo, metallic, roughness);
		  	
			if (g_bFogEnabled)
			{
				output.rgb = add_fog(output.rgb, input.pos_w.w, input.pos_w.z);
			}		
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
// File: meshDecal1Bump.fx
//--------------------------------------------------------------------------------------
    