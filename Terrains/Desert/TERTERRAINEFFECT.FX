//--------------------------------------------------------------------------------------
// File: terTerrainEffect.fx
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

cbuffer cbConstant
{
	static const float	EndFadeDist1 = 2500.0;
	static const float	EndFadeDist2 = 8000.0;
	static const float	NoiseScale = 0.003;
	static const float	StartFadeDist = 800.0;
}

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
};

cbuffer cbPerMesh
{
	float3		g_MeshOffsetPos;
	int			g_NumPointLights;
    PointLight	g_aPointLights[8];
	int			g_NumSpotLights;
    SpotLight	g_aSpotLights[2];
};

cbuffer cbPerMaterial
{
  	float		g_BumpAmount;
};

Texture2D g_MaterialTexture;
Texture2D g_BumpTexture  <string ResourceAddress = "NoiseNormal.bmp"; >;

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
	float4 	uv			: TEXCOORD;			//xy = uv0, zw = uv1
 
    float4	pos			: SV_POSITION;
};

struct PS_INPUT
{
  	float4	pos_w		: COLOR0;			//xyz = world space pos, w = fogdist
	float4 	norm_w		: COLOR1;			//xyz = world space normal, w = bump amount
	float4 	uv			: TEXCOORD;			//xy = uv0, zw = uv1
};

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
				
	return diffuse;
}

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
	
	return diffuse;	
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

float precision_add_z( const float z1, const float z2, const float z3, const float z4 )
{   
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

	z_add = z_largest - z_err;			// include the lost low part from prev add......
	z_temp = z_sum + z_add;
	z_err = (z_temp - z_sum) - z_add;
	z_sum = z_temp; 
	
	z_add = z4 - z_err;					// include the lost low part from prev add...

	return (z_sum + z_add);	
}

//--------------------------------------------------------------------------------------

float4 compute_pos( const float4 P  )
{    
	float4 pos;

	// try to compute z with minimal loss of precision ... 
	// TK TODO DX11/SM5.0 has double!

	pos.x = P.x * g_mViewProj[0][0] + P.y * g_mViewProj[1][0] + P.z * g_mViewProj[2][0];
	pos.y = P.x * g_mViewProj[0][1] + P.y * g_mViewProj[1][1] + P.z * g_mViewProj[2][1];

	pos.z = precision_add_z(P.x * g_mViewProj[0][2], P.y * g_mViewProj[1][2], P.z * g_mViewProj[2][2], g_mViewProj[3][2]);

	pos.w = P.x * g_mViewProj[0][3] + P.y * g_mViewProj[1][3] + P.z * g_mViewProj[2][3] + g_mViewProj[3][3];

	return (pos);
}

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

    return output;    
 }

//--------------------------------------------------------------------------------------
// PixelShader
//--------------------------------------------------------------------------------------
float4 PS( PS_INPUT input ) : SV_TARGET
{ 
	float3 output;
	const float3 N0 = float3(0,0,1);
 	
	if (input.pos_w.w < g_FogDistance.y)
	{
		output = g_MaterialTexture.Sample(g_TextureClampSampler, input.uv.xy).rgb; 

		const float3 N = normalize(input.norm_w.xyz);
		if (input.norm_w.w > 0.0)
		{
			float3 Nt = g_BumpTexture.Sample(g_BumpSampler, frac(input.uv.zw)).xyz * 2.0 - 1.0;
			
			Nt = lerp(N0, Nt, input.norm_w.w);
			Nt = normalize(Nt);
		
			// do per-pixel light sourcing
			const float3 nT = normalize(float3(N.z, 0.0, -N.x));
			const float3x3 tangent_frame = float3x3(nT, cross(N, nT), N);
			
			output *= compute_per_pixel_ambient_diffuse(tangent_frame, Nt, input.pos_w.xyz);
		}
		else
		{
			output *= compute_per_pixel_ambient_diffuse(N, input.pos_w.xyz);
		}
		
		// do per-pixel linear fog
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
// File: terTerrainEffect.fx
//--------------------------------------------------------------------------------------
    