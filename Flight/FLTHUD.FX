//--------------------------------------------------------------------------------------
// File: fltHUD.fx
// Copyright (c) 2008 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Constant Buffers
//--------------------------------------------------------------------------------------

cbuffer cbGlobal
{
    float	g_InvScreenWidth; 
    float	g_InvScreenHeight;
    float2	g_ViewportTopLeft; 
};

cbuffer cbPerMaterial
{
 	int		g_bClampTexture;
};

Texture2D g_MaterialTexture;

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
    float4 pos		: POSITION; 
    float4 diffuse	: COLOR;
    float2 uv		: TEXCOORD;
};

struct VS_OUTPUT
{
	float4 diffuse	: COLOR;
    float2 uv		: TEXCOORD;

    float4 pos		: SV_POSITION;
};

struct PS_INPUT
{
	float4 diffuse	: COLOR;
    float2 uv		: TEXCOORD;
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT VS( VS_INPUT input )
{    
    VS_OUTPUT output;
    
    //convert from screen coordinates to clip space coordinates
    output.pos.x = (input.pos.x - g_ViewportTopLeft.x) * 2.0f * g_InvScreenWidth - 1.0f;
    output.pos.y = 1.0f - (input.pos.y - g_ViewportTopLeft.y) * 2.0f * g_InvScreenHeight;
    output.pos.z = input.pos.z;
    output.pos.w = input.pos.w;

	output.diffuse = input.diffuse;
	output.uv = input.uv;
	
    return output;    
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

float4 PS( PS_INPUT input ) : SV_TARGET
{
	float4 output;
	
	if (!g_bClampTexture)
	{
		output = g_MaterialTexture.Sample(g_TextureWrapSampler, input.uv);
	}
	else
	{
		output = g_MaterialTexture.Sample(g_TextureClampSampler, input.uv);
	}	

	output *= input.diffuse;
    output.a *= HUD_ALPHA;

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
// File: fltHUD.fx
//--------------------------------------------------------------------------------------
