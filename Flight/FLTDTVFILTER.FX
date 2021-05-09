//--------------------------------------------------------------------------------------
// File: fltDTVFilter.fx
// Copyright (c) 2009 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------
  
Texture2D g_RenderedScene;

SamplerState PointSampler
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
}; 

SamplerState LinearSampler
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

//--------------------------------------------------------------------------------------
// color space conversion functions
//--------------------------------------------------------------------------------------

float3 GetYxyFromRGB(uniform float3 vRGB)
{
    // RGB -> XYZ conversion ( http://www.w3.org/Graphics/Color/sRGB )
	
	const float3x3 RGB2XYZ = {	0.5141f, 0.3239f, 0.1604f, 
								0.2651f, 0.6702f, 0.0641f, 
								0.0241f, 0.1228f, 0.8444f };
    const float3 vXYZ = mul(RGB2XYZ, vRGB);
    
    // XYZ -> Yxy conversion: X = Y, x = X / (X + Y + Z), y = Y / (X + Y + Z) 
	
	const float inv_XYZ = 1.0f / (vXYZ.r + vXYZ.g + vXYZ.b + 0.0001f);
	
	return ( float3(vXYZ.g, vXYZ.r * inv_XYZ, vXYZ.g * inv_XYZ) );    
};

float3 GetRGBFromYxy(uniform float3 vYxy)
{
	float3 vRGB = float3(0.0f, 0.0f, 0.0f);
	
	// make sure intesity is positive
	if (vYxy.r > 0.0f)
	{
		// Yxy -> XYZ conversion 
		const float inv_Yxy = 1.0f / (vYxy.b + 0.0001f);
		const float3 vXYZ = float3(	vYxy.r * vYxy.g * inv_Yxy,
									vYxy.r,
									vYxy.r * (1.0f - vYxy.g - vYxy.b) * inv_Yxy );

		// XYZ -> RGB conversion 
		
		const float3x3 XYZ2RGB = {	2.5651f,-1.1665f,-0.3986f, 
								   -1.0217f, 1.9777f, 0.0439f, 
									0.0753f,-0.2543f, 1.1892f };
									
		vRGB = max(0, mul(XYZ2RGB, vXYZ));	// make sure rbg values are positive!
	}
	return (vRGB);
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

struct VS_INPUT
{
    float4 pos		: POSITION; 
    float2 uv		: TEXCOORD;
};

struct VS_OUTPUT
{
    float2 uv		: TEXCOORD;
    
    float4 pos		: SV_POSITION;
};

struct PS_INPUT
{
    float2 uv		: TEXCOORD;
};

#include "CONFIG_FX.H"
#include "FX_COMMON.H"
   
//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT VS( VS_INPUT input )
{    
    VS_OUTPUT output;
   
	output.uv = input.uv;
	output.pos = input.pos;
	
    return output;    
}

//--------------------------------------------------------------------------------------
// Pixel Shaders
//--------------------------------------------------------------------------------------
//g_RenderedScene: rendered scene texture

float PS ( PS_INPUT input ) : SV_TARGET
{    
	const float3 RGB2Lum = { 0.2125f, 0.7154f, 0.0721f };
	
	float4 output;
	
    float3 vColor = SampleChromaticAberration(g_RenderedScene, PointSampler, input.uv, TV_CA_OFFSET, TV_CA_STRENGTH);
	float fLum = dot( vColor, RGB2Lum );
	
	output.r = float4( fLum, fLum, fLum, 1.0f );	

    return (output);
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
// File: fltDTVFilter.fx
//--------------------------------------------------------------------------------------

