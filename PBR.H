#include "PBR_CONFIG.H"

const float PI = 3.14159265359;

float3 fresnelSchlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}  

float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max((1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}   

float DistributionGGX(float3 N, float3 H, float roughness)
{
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
	
    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
	
    return num / denom;	
}

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

float4 CalculateLightReflectance(float3 lightPos, float3 color, float3 worldPos, float3 F0, float3 N, float4 albedo, float roughness, float metallic)
{
	float3 V = -normalize(worldPos);

    // calculate per-light radiance
    float3 L = normalize(lightPos - worldPos);
	float3 H = normalize(V + L);
	float distance = length(lightPos - worldPos);
    float attenuation = 1.0f / (distance * distance);
	float3 radiance = color * attenuation;
	
    // cook-torrance brdf
	float NDF = DistributionGGX(N, H, roughness);
	float G = GeometrySmith(N, V, L, roughness);
	float3 F = fresnelSchlick(max(dot(H, V), 0.0), F0); 
	
	float3 kS = F;
	float3 kD = 1.0 - kS;
	kD *= 1.0 - metallic;
	
	float3 numerator = NDF * G * F;
	float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
	float3 specular = numerator / max(denominator, 0.001);
	
    // return outgoing radiance Lo
	float NdotL = max(dot(N, L), 0.0);
	return float4((kD * albedo / PI + specular) * radiance * NdotL, 1);
}

float4 Pbr(PS_INPUT input, float3 normal, float4 albedo, float4 irradiance, float metallic, float roughness, float ao)
{
	// Degamma diffuse texture
	// irradiance = pow(irradiance, 2.2);
	albedo = pow(albedo, 2.2);

	// Bumpmap normal
	// float3 Nt = lerp(float3(0.0,0.0,1.0), Np, g_BumpAmount);
	// Nt = normalize(Nt);

	// float3 N = normalize(input.norm_w);	// texture normal
	float3 V = -normalize(input.pos_w.xyz);
	
	float3 F0 = 0.04;
    F0 = lerp(F0, albedo, metallic);
	
	float4 Lo = float4(0.0, 0.0, 0.0, 0.0);
	
	// Sun lighting (todo: add other lights)
	float3 sunPos = input.pos_w.xyz - g_DirLight.dir;

	Lo += CalculateLightReflectance(sunPos, g_DirLight.color, input.pos_w.xyz, F0, normal, albedo, roughness, metallic);

    // Point lights
    [unroll(8)]
	for (int i = 0; i < g_NumPointLights; i++)
	{
		Lo += CalculateLightReflectance(g_aPointLights[i].pos, g_aPointLights[i].color, input.pos_w.xyz, F0, normal, albedo, roughness, metallic);
	}
	
    float3 F = fresnelSchlickRoughness(max(dot(normal, V), 0.0), F0, roughness);

    // Ambient lighting via irradiance
    float3 kD = 1.0 - F;
    kD *= 1.0 - metallic;
    float3 diffuse = irradiance * albedo;

    #if PBR_SPECULAR
        // Specular
        const float MAX_REFLECTION_LOD = 4.0;
        float3 prefilteredColor = reflection;
        float2 brdf = reflection.rg;
        float3 specular = prefilteredColor * (F * brdf.x + brdf.y);

        float3 ambient = (kD * diffuse + specular) * ao;
    #else
        float3 ambient = (kD * diffuse) * ao;
    #endif

	float4 color = float4(ambient, albedo.a) + Lo;
    
    // Tonemap HDR and gamma
	// color = color / (color + 1.0);
	color = pow(color, 1.0/2.2);
		
	return color;
}