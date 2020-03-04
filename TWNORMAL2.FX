//--------------------------------------------------------------------------------------
// File: twNormal2.fx
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
    float3		g_CameraPos;
	int			g_bInReflection;
};

cbuffer cbPerMaterial
{
 	int			g_NumTextures;
	int			g_bFogEnabled;
 	int			g_bLightEnabled;
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

Texture2D g_MaterialTexture0;
Texture2D g_MaterialTexture1;

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
	float2	uv0			: TEXCOORD0;
	float2	uv1			: TEXCOORD1;
};

struct VS_OUTPUT
{
	float3 	diffuse		: COLOR0;
	float3 	specular	: COLOR1;
 	float4 	pos_w		: COLOR2;				//xyz = world space pos, w = fogdist
	float3 	norm_w		: COLOR3;				//world space normal
	float2 	uv0			: TEXCOORD0;
    float2 	uv1			: TEXCOORD1;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
	float3 	diffuse		: COLOR0;
	float3 	specular	: COLOR1;
 	float4 	pos_w		: COLOR2;				//xyz = world space pos, w = fogdist
	float3 	norm_w		: COLOR3;				//world space normal
	float2 	uv0			: TEXCOORD0;
    float2 	uv1			: TEXCOORD1;
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
			
	output.uv0 = input.uv0;
	output.uv1 = input.uv1;
	output.pos_w.xyz = P.xyz;
	
	if (g_bLightEnabled)
	{
	 	const float3 L = -g_DirLight.dir;
		const float3 N = mul(input.norm, (float3x3)g_mMeshToWorld);	

 		output.norm_w = N;
 		output.diffuse = g_AmbientLight + g_DirLight.color * max(0, dot(N, L));
	
		// do per-vertex specular lighting
		output.specular = float3(0.0, 0.0, 0.0);
		if (g_bSpecularEnabled && (g_SpecularPower > 1.0))
		{
			const float3 H = -normalize(P.xyz) + L;
			const float h_dot_n = dot(H, N);
			if (h_dot_n > 0.0)
			{
				const float unit_h_dot_n = min(1.0, h_dot_n / length(H));
				output.specular = pow(abs(unit_h_dot_n), g_SpecularPower) * g_SpecularColor;
			}
		}
	}
	else
	{
		output.norm_w = float3(0.0, 0.0, 0.0);
		output.diffuse = float3(1.0, 1.0, 1.0);
		output.specular = float3(0.0, 0.0, 0.0);
	}
	
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
	const float metallic = TWNORMAL_SPECULAR;
	const float roughness = TWNORMAL_ROUGHNESS;
	
	if (g_bInReflection)
	{
		clip(input.pos_w.z + g_CameraPos.z);
	}
			
	float4 albedo;	
	float4 output;
	
	if (!g_bFogEnabled || (input.pos_w.w < g_FogDistance.y))
	{
		albedo = g_MaterialTexture0.Sample(g_TextureWrapSampler, input.uv0);
  
  		if (g_NumTextures > 1)
		{
			const float4 stage = g_MaterialTexture1.Sample(g_TextureWrapSampler, input.uv1);
  			albedo.rgb = albedo.rgb * (1.0 - stage.a) + stage.rgb * stage.a;
		}
		
		// Calculate PBR
		output = Pbr(input, input.norm_w, albedo, metallic, roughness);
		
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
// File: twNormal2.fx
//--------------------------------------------------------------------------------------
    
