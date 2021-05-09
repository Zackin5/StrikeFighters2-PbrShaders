
#include "PBR_CONFIG.H"
#include "PBR_COMMON.H"

// Black Ops 2 BRDF
float2 EnvironmentBRDF( float g, float vdotN)
{
    g = 1.0 - g;
	float4 t = float4( 1.0 / 0.96, 0.475, ( 0.0275 - 0.25 * 0.04 ) / 0.96, 0.25 );
	t *= float4( g, g, g, g );
	t += float4( 0.0, 0.0, ( 0.015 - 0.75 * 0.04 ) / 0.96, 0.75 );
	half a0 = t.x * min( t.y, exp2( -9.28 * vdotN ) ) + t.z;
	half a1 = t.w;
	
	return float2(a0, a1);
}
