//--------------------------------------------------------------------------------------
// File: twNormal1Bump.fx
// Copyright (c) 2009 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------

#include "PBR.FX"

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

//--------------------------------------------------------------------------------------

float3x3 compute_tangent_frame(float3 N, float3 P, float2 uv)
{
	// get edge vectors of the pixel triangle
	const float3 dp1 = ddx(P);
	const float3 dp2 = ddy(P);
	const float2 duv1 = ddx(uv);
	const float2 duv2 = ddy(uv);

	// solve the linear system
	const float2x3 M = float2x3(dp1, dp2);
	const float3 T = mul(float2(duv1.x, duv2.x), M);
	const float3 B = mul(float2(duv1.y, duv2.y), M);

	// construct tangent frame
	float3 bT = normalize( cross(N, T) );
	const float3 nT = cross(bT, N);
	if (dot(bT, B) < 0)
	{
		bT *= -1.0f;
	}	
	return float3x3( nT, bT, N);
}

//--------------------------------------------------------------------------------------

float3 compute_per_pixel_ambient_diffuse(float3x3 TangentFrame, float3 Nt, float3 P)
{
	const float3 light_t = mul(TangentFrame, -g_DirLight.dir);
	
	float3 diffuse = g_AmbientLight + g_DirLight.color * max(0, dot(Nt, light_t));

	// do per-pixel light sourcing for point/spot lights
	for (int i = 0; i < g_NumPointLights; i++)
	{
		const float3 L = g_aPointLights[i].pos - P;
		const float L2 = dot(L, L);
		if (L2 < g_aPointLights[i].Range2)
		{
			const float3 Lt = mul(TangentFrame, L);
			const float n_dot_l = dot(Nt, Lt);
			if (n_dot_l > 0.0)
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
			const float3 Lt = mul(TangentFrame, L);
			const float n_dot_l = dot(Nt, Lt);
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
				
	return saturate(diffuse);
}

//--------------------------------------------------------------------------------------

float3 compute_per_pixel_specular(float3x3 TangentFrame, float3 Nt, float3 P)
{
	float3 specular = 0.0;
	
	if (g_SpecularPower > 1.0)
	{
		const float3 H = -normalize(P) - g_DirLight.dir;
		const float3 Ht = mul(TangentFrame, H);
		
		const float h_dot_n = dot(Ht, Nt);
		if (h_dot_n > 0.0)
		{
			const float unit_h_dot_n = min(1.0, h_dot_n / length(Ht));
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

const float metallic = 0.5f;
const float roughness = 0.35f;

float4 PS( PS_INPUT input ) : SV_TARGET
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
		albedo = g_MaterialTexture.Sample(g_TextureClampSampler, input.uv) ;
		Np = g_BumpNormalTexture.Sample(g_BumpClampSampler, input.uv).xyz * 2.0 - 1.0;
	}

	float3 N = normalize(input.norm_w);	// texture normal
	float3 V = -normalize(input.pos_w.xyz);
	
	float3 F0 = float3(0.04, 0.04, 0.04);
    F0 = lerp(F0, albedo, metallic);
	
	float4 Lo = float4(0.0, 0.0, 0.0, 0.0);
	
	// sun lighting (todo: add other lights)
	float3 sunPos = input.pos_w.xyz - g_DirLight.dir;

	Lo += CalculateLightReflectance(sunPos, g_DirLight.color, input.pos_w.xyz, F0, N, albedo, roughness, metallic);
	
	// finalize
	float4 ambient = float4(g_AmbientLight, 1) * albedo;
	float4 color = ambient + Lo;
	
	// tonemapping
	color = color / (color + 1.0);
	color = pow(color, 1.0/2.0);
	
	// TODO: apply specular on top of alpha
	return color;

	/*if (g_bInReflection)
	{
		clip(input.pos_w.z + g_CameraPos.z);
	}
		
	float4 output;
	
	if (g_bInReflection)
	{
		clip(input.pos_w.z + g_CameraPos.z);
	}
			
	if (!g_bFogEnabled || (input.pos_w.w < g_FogDistance.y))
	{
		float3 Np;

		if (!g_bClampTexture)
		{
			output = g_MaterialTexture.Sample(g_TextureWrapSampler, input.uv);
			Np = g_BumpNormalTexture.Sample(g_BumpWrapSampler, input.uv).xyz * 2.0 - 1.0;
		}
		else
		{
			output = g_MaterialTexture.Sample(g_TextureClampSampler, input.uv) ;
			Np = g_BumpNormalTexture.Sample(g_BumpClampSampler, input.uv).xyz * 2.0 - 1.0;
		}
		 
		if (output.a > 0.0)
		{           	
			if (g_bLightEnabled)
			{
				// do per-pixel light sourcing
				const float3 N0 = normalize(input.norm_w);
				const float3x3 tangent_frame = compute_tangent_frame(N0, input.pos_w.xyz, input.uv);
						
				float3 Nt = lerp(float3(0.0,0.0,1.0), Np, g_BumpAmount);
				Nt = normalize(Nt);
	
				output.rgb *= compute_per_pixel_ambient_diffuse(tangent_frame, Nt, input.pos_w.xyz);
				output.rgb += compute_per_pixel_specular(tangent_frame, Nt, input.pos_w.xyz);
			}
								     
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

	return output;*/
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
    
