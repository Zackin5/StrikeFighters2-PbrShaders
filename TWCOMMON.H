//--------------------------------------------------------------------------------------
// Commonly used ThirdWire shader functions
// Copyright (c) 2009 Third Wire Productions, Inc.
//--------------------------------------------------------------------------------------

#ifndef TW_COMMON
#define TW_COMMON

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

float3 CalculateSpotLightRadiance(float3 color, float3 lightPos, float3 worldPos, float invRange, float range2)
{
	float3 radiance = 0.0;

	const float3 L = lightPos - worldPos;
	const float L2 = dot(L, L);
	if (L2 < range2)
	{
		const float lenL = sqrt(L2);
		const float Ln = lenL * invRange;
		float cp = 0;
		if (Ln < 0.5)
		{
			cp = 1.0-2.0*Ln*Ln;
		}
		else
		{
			cp = 2*(1.0-Ln)*(1.0-Ln);
		}

		radiance = color * cp;
	}

	return radiance;
}

#endif