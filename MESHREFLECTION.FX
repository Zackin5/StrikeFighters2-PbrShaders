//--------------------------------------------------------------------------------------
// File: meshReflection.fx
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
 	int			g_bClampTexture;
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
	int			g_NumSpotLights;
    PointLight	g_aPointLights[8];
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
};

struct VS_OUTPUT
{
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
    float2	uv0			: TEXCOORD0;
    float2	uv1			: TEXCOORD1;

    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
 	float4	pos_w		: COLOR0;				//xyz = world space pos, w = fogdist
	float3	norm_w		: COLOR1;				//world space normal
    float2	uv0			: TEXCOORD0;
    float2	uv1			: TEXCOORD1;
};

//--------------------------------------------------------------------------------------
		
float3 compute_per_pixel_ambient_diffuse(float3 N, float3 P)
{
	float3 diffuse = g_AmbientLight + g_DirLight.color * max(0, dot(N, -g_DirLight.dir));

	// do per-pixel light sourcing for point/spot lights
	for (int i = 0; i < g_NumPointLights; i++)
	{
		const float3 L = g_aPointLights[i].pos - P;
		const float L2 = dot(L, L);
		if (L2 < g_aPointLights[i].Range2)
		{
			const float n_dot_l = dot(N, L);			
			if (n_dot_l > 0)
			{
				const float lenL = sqrt(L2);
				const float Ln = lenL * g_aPointLights[i].invRange;
				float cp = 0;
				if (Ln < 0.5)
				{
					cp = 1.0-2.0*Ln*Ln;
				}
				else
				{
					cp = 2*(1.0-Ln)*(1.0-Ln);
				}
				cp *= (n_dot_l / lenL);
				diffuse += (g_aPointLights[i].color * cp);
			}
		}
	}
	for (int j = 0; j < g_NumSpotLights; j++)
	{
		const float3 L = g_aSpotLights[j].pos - P;
		const float L2 = dot(L, L);
		if (L2 < g_aSpotLights[j].Range2)
		{
			const float n_dot_l = dot(N, L);
			if (n_dot_l > 0.0)
			{
				const float lenL = sqrt(L2);
				const float inv_lenL = 1.0 / lenL;
				const float3 Lu = -L * inv_lenL;
				const float ca = dot(Lu, g_aSpotLights[j].dir);
				if (ca > g_aSpotLights[j].angles.y)
				{
					const float Ln = lenL * g_aSpotLights[j].invRange;
					float cp = 0;
					if (Ln < 0.5)
					{
						cp = 1.0-2.0*Ln*Ln;
					}
					else
					{
						cp = 2*(1.0-Ln)*(1.0-Ln);
					}
					if (ca < g_aSpotLights[j].angles.x)
					{
						cp *= (ca - g_aSpotLights[j].angles.y) * g_aSpotLights[j].angles.z;
					}						
					cp *= (n_dot_l * inv_lenL);
					diffuse += (g_aSpotLights[j].color * cp);
				}
			}
		}
	}	
	
	return (saturate(diffuse));
}

//--------------------------------------------------------------------------------------

float3 compute_per_pixel_specular(float3 N, float3 P)
{
	float3 specular = float3(0.0f, 0.0f, 0.0f);
	
	if (g_SpecularPower > 1.0)
	{
		const float3 H = -normalize(P) - g_DirLight.dir;
	
		const float h_dot_n = dot(H, N);
		if (h_dot_n > 0.0)
		{
			const float unit_h_dot_n = min(1.0, h_dot_n / length(H));
			specular = (pow(unit_h_dot_n, g_SpecularPower) * g_SpecularColor);
		}
	}
	
	return (specular);
}

//--------------------------------------------------------------------------------------

float3 add_fog(float3 Color, float FogDist, float FogZ)
{
	float3 output = Color;

	float fog = 0.0f;	
	const float fd = FogDist - g_FogDistance.x;
	if (fd > 0.0)
	{
		fog = (fd * g_FogDistance.z);
	}
	if (g_FogLayer.x > 0.0)
	{
		const float fz = abs(FogZ - g_FogLayer.y);
		float depth = g_FogLayer.z - fz;
		if (depth > 0.0)
		{
			depth = min(FogDist, depth);
			
			fog += (g_FogLayer.x * (smoothstep(0.0, g_FogLayer.z, depth)));
		}
	}

	fog = clamp(0.0, 1.0, fog);
	output = lerp(output, g_FogColor, fog);
	
	return (output);
}

//--------------------------------------------------------------------------------------

float4 compute_pos( const float4 P  )
{    
	float4 pos;

//	output.pos = mul(P, g_mViewProj);		// instead of this...

	// try to compute z with minimal loss of precision ... 
	// TK TODO DX11/SM5.0 has double!

	pos.x = P.x * g_mViewProj[0][0] + P.y * g_mViewProj[1][0] + P.z * g_mViewProj[2][0];
	pos.y = P.x * g_mViewProj[0][1] + P.y * g_mViewProj[1][1] + P.z * g_mViewProj[2][1];
	
	const float z1 = P.x * g_mViewProj[0][2];
	const float z2 = P.y * g_mViewProj[1][2];
	const float z3 = P.z * g_mViewProj[2][2];
	
	float z_sum = 0.0;
	float z_add = 0.0;
	float z_largest = 0.0;
	float z_temp = 0.0;
	float z_err = 0.0;

	if (z1 > z2)
	{
		z_sum = z2;
		if (z1 > z3)
		{
			z_largest = z1;
			z_add = z3;
		}
		else
		{
			z_largest = z3;
			z_add = z1;
		}
	}
	else
	{
		z_sum = z1;
		if (z2 > z3)
		{
			z_largest = z2;
			z_add = z3;
		}
		else
		{
			z_largest = z3;
			z_add = z2;
		}
	}
	
	// use Kahan summation
	z_temp = z_sum + z_add;				// if z_sum is big and z_add small, low-order digits can get lost...
	z_err = (z_temp - z_sum) - z_add;	// recover the lost digits...
	z_sum = z_temp; 

	z_add = z_largest - z_err;			// include the lost low part from last add......
	z_temp = z_sum + z_add;
	z_err = (z_temp - z_sum) - z_add;
	z_sum = z_temp; 
	
	z_add = g_mViewProj[3][2] - z_err;	// include the lost low part from last add...

	pos.z = z_sum + z_add;	
	
	pos.w = P.x * g_mViewProj[0][3] + P.y * g_mViewProj[1][3] + P.z * g_mViewProj[2][3] + g_mViewProj[3][3];

	return (pos);
}

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
	output.uv1.x = 0.5 * Nv.x + 0.5;
	output.uv1.y = -0.5 * Nv.y + 0.5;
		
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

#include "PBR.FX"

float4 PS( PS_INPUT input ) : SV_TARGET
{
	const float metallic = 0.5f;
	const float roughness = 0.5f;
	const float ao = 1.0f;

	if (g_bInReflection)
	{
		clip(input.pos_w.z + g_CameraPos.z);
	}
				
	const float4 reflec = g_MaterialTexture1.Sample(g_TextureClampSampler, input.uv1);
	float4 albedo;
	float4 output;
	
	if (!g_bFogEnabled || (input.pos_w.w < g_FogDistance.y))
	{
		if (!g_bClampTexture)
		{
			albedo = g_MaterialTexture0.Sample(g_TextureWrapSampler, input.uv0);
		}
		else
		{
			albedo = g_MaterialTexture0.Sample(g_TextureClampSampler, input.uv0);
		}
		 		
		if (albedo.a > 0)
		{ 
			output = Pbr(input, albedo, reflec, reflec.a, roughness, ao);				
					  	
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
// File: meshReflection.fx
//--------------------------------------------------------------------------------------
    