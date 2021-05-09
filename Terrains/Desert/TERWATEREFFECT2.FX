//--------------------------------------------------------------------------------------
// File: terWaterEffect2.fx
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

cbuffer cbConstant
{
	static const float		EndFadeDist1 = 2500.0;
	static const float		EndFadeDist2 = 8000.0;
	static const float		NoiseScale = 0.003;
	static const float		StartFadeDist = 800.0;
	static const float		WaveCycleRate = 1.3;
	static const float		WaveNoiseScale = 0.0005;
	static const float		WaveBumpAmount = 2.00;
	static const float		WaveStartFadeDist = 1000.0;
//	static const float		WaveEndFadeDist = 12000.0;
	static const float		WaveFadeFactor = 0.0000909;	// 1 / (WaveEndFadeDist - WaveStartFadeDist)
	static const float		WaveMovementRate = 0.0003;
	static const float3		WindVelocity = { 3.0, -6.0, 0.0 };
};

cbuffer cbGlobal
{
    float4x4	g_mWorldToView;
    float4x4	g_mViewProj;
	float3		g_FogDistance;		// x = Start, y = End, z =  1 / (y - x)
    float3		g_FogColor;
    float3		g_FogLayer;			// x = amount, y = altitude (camera-relative), z = thickness
	float3		g_AmbientLight;
	DirLight	g_DirLight;
	float		g_TimeNow;
    float3		g_CameraPos;
//	float3		g_WindVelocity;
};

cbuffer cbPerMaterial
{
	float		g_SpecularPower;
  	float3		g_SpecularColor;	// specular level * dir light specular color * mat specular color
  	float		g_BumpAmount;
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
Texture2D g_BumpTexture  <string ResourceAddress = "NoiseNormal.bmp"; >;
Texture2D g_WaveTexture  <string ResourceAddress = "WaterNormal.bmp"; >;

SamplerState g_TextureClampSampler
{
    Filter = ANISOTROPIC;
    AddressU = Clamp;
    AddressV = Clamp;
};

SamplerState g_BumpSampler
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

SamplerState g_WaveSampler
{
    Filter = MIN_MAG_LINEAR_MIP_POINT;
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
  	float4	pos_w		: COLOR0;			//xyz = world space pos, w = fogdist
	float4 	norm_w		: COLOR1;			//xyz = world space normal, w = bump amount  	
	float4 	uv			: TEXCOORD0;		//xy = uv0, zw = uv1
	float4 	wave		: TEXCOORD1;		//xy = wave, zw = uv2

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
  	float4	pos_w		: COLOR0;			//xyz = world space pos, w = fogdist
	float4 	norm_w		: COLOR1;			//xyz = world space normal, w = bump amount
	float4 	uv			: TEXCOORD;			//xy = uv0, zw = uv1
	float4 	wave		: TEXCOORD1;
};

#include "..\..\Flight\TWCOMMON.H"

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT VS( VS_INPUT input )
{
    VS_OUTPUT output;
    
	const float4 P = float4((input.pos + g_MeshOffsetPos), 1.0);	// position, world-space	
	const float4 Pv = mul(P, g_mWorldToView);						// position in view-space

//	output.pos = mul(P, g_mViewProj);		
	output.pos = compute_pos(P);

	output.pos_w.xyz = P.xyz;
	output.pos_w.w = Pv.z;
	
	output.norm_w.xyz = input.norm;
	output.uv.xy = input.uv;

	// terrain
	if ((g_BumpAmount > 0.0) && (Pv.z < EndFadeDist2))
	{
		output.uv.zw = NoiseScale*P.xy + NoiseScale*g_CameraPos.xy;

		const float3 I = -normalize(P.xyz);
		const float fade_end = lerp(EndFadeDist1, EndFadeDist2, max(0.0, I.z));
  		output.norm_w.w = clamp(0.0, 1.0, g_BumpAmount * (1.0 - ((Pv.z - StartFadeDist) / (fade_end - StartFadeDist))));
  	}
  	else
  	{
  		output.uv.zw = float2(0.0,0.0);
		output.norm_w.w = 0;
  	}

	// water
  	output.wave.y = clamp(0.0, 1.0, WaveBumpAmount * (1.0 - (Pv.z - WaveStartFadeDist) * WaveFadeFactor));
   	if (output.wave.y > 0.0)
   	{
		const float sin_wave = sin(float(WaveCycleRate*g_TimeNow + WaveNoiseScale*((P.x - P.y) + (g_CameraPos.x - g_CameraPos.y))));
		
		output.wave.x = 0.5 * (sin_wave + 1.0);
   		output.wave.zw = WaveNoiseScale*P.xy + WaveNoiseScale*g_CameraPos.xy + g_TimeNow*WaveMovementRate*WindVelocity.xy;
	}
	else
	{
		output.wave.x = 0.0;
		output.wave.zw = float2(0.0,0.0);
	}
	
    return output;    
}

//--------------------------------------------------------------------------------------
// PixelShader
//--------------------------------------------------------------------------------------
#include "PBR.H"

float4 PS( PS_INPUT input ) : SV_TARGET
{ 
	const float ter_metallic = TERRAIN_METALLIC;
	const float ter_roughness = TERRAIN_ROUGHNESS;
	const float wtr_metallic = WATER_METALLIC;
	const float wtr_roughness = WATER_ROUGHNESS;

	float4 output;
	const float3 N0 = float3(0,0,1);
	 
	if (input.pos_w.w < g_FogDistance.y)
	{
		float4 albedo = g_MaterialTexture.Sample(g_TextureClampSampler, input.uv.xy);
		float3 water_diff = output.rgb;
		float3 land_diff = output.rgb;

		if (albedo.a > 0.0)
		{		
			// water area	
			if (input.wave.y > 0.0)
			{
				const float2 nt = frac(input.wave.zw);
				
				const float3 N1 = g_WaveTexture.Sample(g_WaveSampler, float2(nt.x + 0.5, nt.y + 0.5)).xyz;
				float3 N2 = g_WaveTexture.Sample(g_WaveSampler, nt).xyz;
				
				N2 = lerp(N1, N2, input.wave.x) * 2.0 - 1.0;
				N2 = lerp(N0, N2, input.wave.y);
				N2 = normalize(N2);
			
				water_diff = Pbr(input, N2, albedo, wtr_metallic, wtr_roughness);
			}
			else
			{
				water_diff = Pbr(input, N0, albedo, wtr_metallic, wtr_roughness);
			}
		}
		if (albedo.a < 1.0)
		{
			// non-water
			const float3 N = normalize(input.norm_w.xyz);
			if (input.norm_w.w > 0.0)
			{
				float3 Nt = g_BumpTexture.Sample(g_BumpSampler, frac(input.uv.zw)).xyz * 2.0 - 1.0;
				
				Nt = lerp(N0, Nt, input.norm_w.w);
				Nt = normalize(Nt);
				
				land_diff = Pbr(input, Nt, albedo, ter_metallic, ter_roughness);
			}
			else
			{
				land_diff = Pbr(input, N, albedo, ter_metallic, ter_roughness);
			}
		}
		
		land_diff = lerp(land_diff, water_diff, albedo.a);
					
		output.rgb = add_fog(land_diff, input.pos_w.w, input.pos_w.z);
	}	
	else
	{
		output.rgb = g_FogColor;
	}
	
	return (float4(saturate(output.rgb), 1.0));
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
// File: terWaterEffect2.fx
//--------------------------------------------------------------------------------------
    