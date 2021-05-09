//--------------------------------------------------------------------------------------
// Copyright (c) 2006 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------
int GlobalParameter : SasGlobal
<
    int3 SasVersion = {1, 1, 0};
    
    string SasEffectDescription = "Far Terrain Shader";
    string SasEffectCompany = "Third Wire Productions, Inc.";
>;

//--------------------------------------------------------------------------------------
// Variables
//--------------------------------------------------------------------------------------
struct SasPointLight
{
    float3	Color;
    float3	Position;
    float	Range;
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

const float2 FogDistance		: FOG_DISTANCE;

texture MaterialTexture;

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

//--------------------------------------------------------------------------------------
// VertexShader I/O
//--------------------------------------------------------------------------------------
struct VS_INPUT
{
    float3	Pos			: POSITION; 
    float3	Norm		: NORMAL;
	float2	Tex			: TEXCOORD0;
};

struct VS_OUTPUT
{
    float4	Pos			: POSITION; 
	float3	Diffuse		: COLOR0;
	float2	Tex			: TEXCOORD0; 
    float3	Norm		: TEXCOORD1;
	float3	PosWorld	: TEXCOORD2;
	float	Fog			: FOG;
};

//--------------------------------------------------------------------------------------
		
float3 compute_per_pixel_light_source(float3 AmbientDiffuse, float3 N, float3 P)
{
	float3 diffuse = AmbientDiffuse;
	
	const float3 L = PointLight.Position - P; 
	const float L2 = dot(L, L);
	if (L2 < (PointLight.Range*PointLight.Range))
	{
		const float n_dot_l = dot(N, L);			
		if (n_dot_l > 0)
		{
			const float3 Ln = L / (PointLight.Range+0.0001);
			const float cp = n_dot_l / (sqrt(L2) * (1.0 + 6.0 * dot(Ln, Ln)));
		
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
	const float4 Pv = mul(P, View);		// position in view-space, for fog computation

	const float3 N = mul(input.Norm, (float3x3)World);	
 
	output.Pos = mul(P, ViewProj);		
	output.Tex = input.Tex;
	output.Diffuse = AmbientLight + (LightColor * dot(N, -LightDir));
	output.Norm = N;	

	output.PosWorld = P.xyz;

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
	float3 diff = input.Diffuse;
	float3 sample0 = tex2D(TextureSampler, input.Tex).xyz;
	
	if (NumPointLights > 0)	
	{
		diff = compute_per_pixel_light_source(diff, input.Norm, input.PosWorld);
	}
	
	diff *= sample0.rgb;
	return (float4(diff, 1.0) );
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
