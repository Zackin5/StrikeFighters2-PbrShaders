
#include "PBR_CONFIG.H"
#include "PBR_COMMON.H"

// OpenGL tutorial BRDF

float RadicalInverse_VdC(uint bits) 
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

float2 Hammersley(uint i, uint N)
{
    return float2(float(i)/float(N), RadicalInverse_VdC(i));
}

float3 ImportanceSampleGGX(float2 Xi, float3 N, float roughness)
{
    float a = roughness * roughness;

    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);

    // Spherical coords to cartesian
    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;

    // Tangent-space vector to world-space
    float3 up = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);

    float3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
}

float4 SampleIBLColor(Texture2D cubemapTex, float3 normal, float roughness)
{
    float3 N = normal;
    float3 R = N;
    float3 V = R;

    float totalWeight = 0.0;
    float3 prefilteredColor = 0.0;

    // [unroll(IBL_SAMPLECOUNT)]
    [fastopt]
    for(uint i = 0u; i < IBL_SAMPLECOUNT; ++i)
    {
        float2 Xi = Hammersley(i, IBL_SAMPLECOUNT);
        float3 H = ImportanceSampleGGX(Xi, N, roughness);
        float3 L = normalize(2.0 * dot(V, H) * H - V);

        float NdotL = max(dot(N, L), 0.0);
        if(NdotL > 0.0)
        {
            prefilteredColor += cubemapTex.Sample(g_TextureClampSampler, L).rgb * NdotL;
            totalWeight += NdotL;
        }
    }
    prefilteredColor = prefilteredColor / totalWeight;

    return float4(prefilteredColor, 1.0);
}

float2 IntegrateBRDF(float NdotV, float roughness)
{
    float3 V;
    V.x = sqrt(1.0 - NdotV*NdotV);
    V.y = 1.0;
    V.z = NdotV;

    float A = 0.0;
    float B = 0.0;

    float3 N = float3(0.0, 0.0, 1.0);

    // [unroll(IBL_SAMPLECOUNT)]
    [fastopt]
    for(uint i = 0u; i < IBL_SAMPLECOUNT; ++i)
    {
        float2 Xi = Hammersley(i, IBL_SAMPLECOUNT);
        float3 H  = ImportanceSampleGGX(Xi, N, roughness);
        float3 L  = normalize(2.0 * dot(V, H) * H - V);
        
        float NdotL = max(L.z, 0.0);
        float NdotH = max(H.z, 0.0);
        float VdotH = max(dot(V, H), 0.0);
        
        if(NdotL > 0.0)
        {
            float G = GeometrySmith(N, V, L, roughness);
            float G_Vis = (G * VdotH) / (NdotH * NdotV);
            float Fc = pow(1.0 - VdotH, 5.0);

            A += (1.0 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }

    A /= float(IBL_SAMPLECOUNT);
    B /= float(IBL_SAMPLECOUNT);
    return float2(A, B);
}

// Black Ops 2 BRDF
float a1vf( float g )
{
	return ( 0.25 * g + 0.75 );
}

float a004( float g, float vdotN )
{
	float t = min( 0.475 * g, exp2( -9.28 * vdotN ) );
	return ( t + 0.0275 ) * g + 0.015;
}

float a0r(float g, float VdotN)
{
    g = 1.0 - g;
    return ((a004(g, VdotN) - a1vf(g) * 0.04) / 0.96);
}

float3 EnvironmentBRDF( float g, float vdotN, float3 color )
{
    g = 1.0 - g;
	float4 t = float4( 1.0 / 0.96, 0.475, ( 0.0275 - 0.25 * 0.04 ) / 0.96, 0.25 );
	t *= float4( g, g, g, g );
	t += float4( 0.0, 0.0, ( 0.015 - 0.75 * 0.04 ) / 0.96, 0.75 );
	half a0 = t.x * min( t.y, exp2( -9.28 * vdotN ) ) + t.z;
	half a1 = t.w;
	
	return saturate( a0 + color * ( a1 - a0 ) );
}

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
