//--------------------------------------------------------------------------------------
// File: meshReflectionDecal1sm.fx
// Copyright (c) 2010 Third Wire Productions, Inc.
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
	int			g_bInReflection;
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
Texture2D g_MaterialTexture1;
Texture2D g_MaterialTexture2;
Texture2D g_MaterialTexture3;

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
	float2	uv0			: TEXCOORD0;
	float2	uv1			: TEXCOORD1;
	float2	uv2			: TEXCOORD2;
	float2	uv3			: TEXCOORD3;
};

struct VS_OUTPUT
{
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
    float2	uv0			: TEXCOORD0;
	float2	uv2			: TEXCOORD1;
	float2	uv3			: TEXCOORD2;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
    float2	uv0			: TEXCOORD0;
	float2	uv2			: TEXCOORD1;
	float2	uv3			: TEXCOORD2;
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

	output.uv0 = input.uv0;
	output.uv2.x = 0.5 * Nv.x + 0.5;
	output.uv2.y = -0.5 * Nv.y + 0.5;
	output.uv3 = input.uv3;
	
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
	const float dMetallic = MESHDECAL_METALLIC;
	const float dRoughness = MESHDECAL_ROUGHNESS;

	if (g_bInReflection)
	{
		clip(input.pos_w.z + g_CameraPos.z);
	}
		
	// PBR irradiance map
	float4 irradiance = CalculateIrradianceMap(g_MaterialTexture3, input.norm_w);
	float mMetallic = MESHREFLECTION_METALLIC * irradiance.a;
	float mRoughness = MESHREFLECTION_ROUGHNESS * (1 - irradiance.a);

	// PBR IBF specular
	float4 specular = g_MaterialTexture3.Sample(g_TextureClampSampler, input.uv3);
	specular = lerp(specular, irradiance, mRoughness);

	float4 albedo;
	float4 output;
	
	if (!g_bFogEnabled || (input.pos_w.w < g_FogDistance.y))
	{
		float3 sm;

		if (!g_bClampTexture)
		{
			albedo = g_MaterialTexture0.Sample(g_TextureWrapSampler, input.uv0);
			sm = g_MaterialTexture1.Sample(g_TextureWrapSampler, input.uv0).rgb;
		}
		else
		{
			albedo = g_MaterialTexture0.Sample(g_TextureClampSampler, input.uv0);
			sm = g_MaterialTexture1.Sample(g_TextureClampSampler, input.uv0).rgb;
		}
		 		
		if (albedo.a > 0.0)
		{     
			// decals at 3   
			float4 decal = g_MaterialTexture3.Sample(g_TextureClampSampler, input.uv3);
			
			// Calculate alpha between decal and surface
			albedo = lerp(albedo, decal, decal.a);
			float metallic = lerp(mMetallic, dMetallic, decal.a);
			float roughness = lerp(1.0 - sm, dRoughness, decal.a);		

			// Calculate PBR
			output = Pbr(input, input.norm_w, albedo, irradiance, specular, metallic, roughness);				
							   
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
// File: meshReflectionDecal1sm.fx
//--------------------------------------------------------------------------------------
