
#ifndef PBR_COMMON
#define PBR_COMMON

const float PI = 3.14159265359;

SamplerState pbr_TextureWrapSampler
{
    Filter = ANISOTROPIC;
    AddressU = Wrap;
    AddressV = Wrap;
};

SamplerState pbr_TextureClampSampler
{
    Filter = ANISOTROPIC;
    AddressU = Clamp;
    AddressV = Clamp;
};

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
	
    return num / denom;
}

float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);
	
    return ggx1 * ggx2;
}

float RgbToLum(float3 rgb)
{
    return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

#endif