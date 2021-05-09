//--------------------------------------------------------------------------------------
// Copyright (c) 2006 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------
int GlobalParameter : SasGlobal
<
    int3 SasVersion = {1, 1, 0};
    
    string SasEffectDescription = "Terrain Shader";
    string SasEffectCompany = "Third Wire Productions, Inc.";
>;

//--------------------------------------------------------------------------------------
// Variables
//--------------------------------------------------------------------------------------
struct SasPointLight
{
    float3 Color;
    float3 Position;
    float  Range;
};

const float4x4 World <string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[0]";>;         
const float4x4 View <string SasBindAddress = "Sas.Camera.WorldToView";>;
const float4x4 ViewProj <string SasBindAddress = "Sas.Camera.WorldViewProj";>;

// light directions in world space
const float3 AmbientLight <string SasBindAddress = "Sas.AmbientLight[0].Color";> = { 0.0, 0.0, 0.6 };
const float3 LightColor <string SasBindAddress = "Sas.DirectionalLight[0].Color";> = { 0.8, 0.8, 0.0 };
const float3 LightDir <string SasBindAddress = "Sas.DirectionalLight[0].Direction";> = {0.447050746,-0.447050746,0.774784655};

const int NumPointLights <string SasBindAddress = "Sas.NumPointLights"; > = 0;
const SasPointLight PointLight <string SasBindAddress = "Sas.PointLight[0]"; >;

const float3 CameraPos			: CAMERA_GLOBAL_POSITION;
const float2 FogDistance		: FOG_DISTANCE;
const float BumpAmount			: BUMP_AMOUNT;

const float StartFadeDist = 800.0;
const float EndFadeDist1 = 2500.0;
const float EndFadeDist2 = 8000.0;
const float NoiseScale = 0.003;

texture MaterialTexture;
texture BumpTexture <string SasResourceAddress = "NoiseNormal.bmp"; >;

//--------------------------------------------------------------------------------------
// Texture samplers
//--------------------------------------------------------------------------------------
sampler TextureSampler = 
sampler_state
{
    Texture = <MaterialTexture>;
    AddressU = CLAMP;
    AddressV = CLAMP;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler BumpSampler = 
sampler_state
{
    Texture = <BumpTexture>;
    AddressU = WRAP;
    AddressV = WRAP;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//--------------------------------------------------------------------------------------
// VertexShader I/O
//--------------------------------------------------------------------------------------
struct VS_INPUT
{
    float3 Pos		: POSITION; 
    float3 Norm		: NORMAL;
	float2 Tex		: TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 Pos		: POSITION; 
	float4 Tex0		: TEXCOORD0;	//xy = uv0, wz = uv1
	float3 LightDir	: TEXCOORD1;
	float3 LightPt	: TEXCOORD2;
	float4 PosWorld	: TEXCOORD3;	// xyz = pos, w = bump amount
	float Fog		: FOG;
};

//--------------------------------------------------------------------------------------
		
float3 compute_per_pixel_light_source(float3 AmbientDiffuse, float3 Nt, float3 Lt, float3 P)
{
	// Lt in tangent space,already noramlized
	float3 diffuse = AmbientDiffuse;
	
	const float3 L = PointLight.Position - P; 
	const float L2 = dot(L, L);
	if (L2 < (PointLight.Range*PointLight.Range))
	{
		const float n_dot_l = dot(Nt, Lt);			
		if (n_dot_l > 0)
		{
			const float3 Ln = L / (PointLight.Range+0.0001);
			const float cp = n_dot_l / (1.0 + 6.0 * dot(Ln, Ln));
		
			diffuse += (PointLight.Color * cp);
		}	
	}
	return (saturate(diffuse));
}
	
//--------------------------------------------------------------------------------------
// This shader computes standard transform and lighting
//--------------------------------------------------------------------------------------
VS_OUTPUT VS( VS_INPUT input )
{
    VS_OUTPUT output;
 
	const float4 P = mul(float4(input.Pos, 1.0), World);	// position, world-space	
	const float4 Pv = mul(P, View);		// position in view-space, for fade computation

	const float3 N = mul(input.Norm, (float3x3)World);	
 
	output.Pos = mul(P, ViewProj);		
	output.Tex0.xy = input.Tex;
	
	// save out LightDir in terrain tangent-space
	float3x3 TangentFrame;
	TangentFrame[0] = normalize(float3(N.z, 0.0, -N.y));
	TangentFrame[1] = cross(N, TangentFrame[0]);
	TangentFrame[2] = N;
	
	output.LightDir = mul(TangentFrame, -LightDir);
	if (NumPointLights > 0)
	{
		output.LightPt = mul(TangentFrame, normalize(PointLight.Position - P.xyz));
	}
	else
	{
		output.LightPt = float3(0,0,0);
	}
	
	output.PosWorld.xyz = P.xyz;
	 
	if ((BumpAmount > 0) && (Pv.z < EndFadeDist2))
	{	 
		output.Tex0.z = NoiseScale*P.x + NoiseScale*CameraPos.x;
		output.Tex0.w = NoiseScale*P.y + NoiseScale*CameraPos.y;
		
		const float3 I = -normalize(P.xyz);					
	 	const float FadeEnd = lerp(EndFadeDist1, EndFadeDist2, max(0.0, I.z));
		const float bv = 1.0 / (FadeEnd - StartFadeDist);
 		output.PosWorld.w = clamp(0.0, 1.0, BumpAmount * (1.0 - (Pv.z - StartFadeDist) * bv));
 	}
 	else
 	{
 		output.Tex0.zw = float2(0,0);
 		output.PosWorld.w = 0.0;
 	}

	if (Pv.z < FogDistance.y)
	{
		const float fv = 1.0 / (FogDistance.y - FogDistance.x);
		output.Fog = clamp(0.0, 1.0, (1.0 - (Pv.z - FogDistance.x) * fv));
	}
	else
	{
		output.Fog = 0.0;
	}

	return output;    
}

//--------------------------------------------------------------------------------------
// PixelShader
//--------------------------------------------------------------------------------------
float4 PS( VS_OUTPUT input ) : COLOR
{ 	
	float3 diff = AmbientLight;
	float3 sample0 = tex2D(TextureSampler, input.Tex0.xy).xyz;
	
	float3 Nt = float3(0,0,1);
	if (input.PosWorld.w > 0)
	{
		const float3 N1 = tex2D(BumpSampler, frac(input.Tex0.zw)) * 2.0 - 1.0;
			
		Nt = lerp(Nt, N1, input.PosWorld.w);
		//Nt = normalize(Nt);
	
		diff += (LightColor * dot(Nt, input.LightDir));
	}
	else
	{
		diff += (LightColor * input.LightDir.z);
	}	
	if (NumPointLights > 0)
	{
		diff = compute_per_pixel_light_source(diff, Nt, input.LightPt, input.PosWorld.xyz);
	}
	
	sample0 *= diff;
	return (float4(saturate(sample0), 1.0));
}

//--------------------------------------------------------------------------------------
// Techniques
//--------------------------------------------------------------------------------------
technique TerrainBump
{
    pass P0
    {   
		SRCBLEND = ONE;
		DESTBLEND = ZERO; 

        VertexShader = compile vs_2_0 VS();
        PixelShader  = compile ps_2_0 PS(); 
 	}
}
