#include "PBR_CONFIG.H"
#include "PBR_COMMON.H"
#include "PBR_SPECULARIBL.H"
#include "TWCOMMON.H"

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
    float NdotH  = saturate(dot(N, H));
    float NdotH2 = NdotH*NdotH;
	
    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
	
    return num / denom;	
}

float3 CalculateLightRadiance(float3 lightPos, float3 worldPos, float3 lightColor)
{
	float distance = length(lightPos - worldPos);
    float attenuation = 1.0f / (distance * distance);
	float3 radiance = lightColor * attenuation;

	return radiance;
}

float3 CalculateLightReflectance(float3 lightPos, float3 radianceColor, float3 worldPos, float3 F0, float3 N, float4 albedo, float roughness, float metallic)
{
	float3 V = -normalize(worldPos);

    // calculate per-light radiance
    float3 L = normalize(lightPos - worldPos);
	float3 H = normalize(V + L);
	
    // cook-torrance brdf
	float NDF = DistributionGGX(N, H, roughness);
	float G = GeometrySmith(N, V, L, roughness);
	float3 F = fresnelSchlick(saturate(dot(H, V)), F0); 
	
	float3 kS = F;
	float3 kD = 1.0 - kS;
	kD *= 1.0 - metallic;
	
	float3 numerator = NDF * G * F;
	float denominator = 4.0 * saturate(dot(N, V)) * saturate(dot(N, L));
	float3 specular = numerator / max(denominator, 0.001);
	
    // return outgoing radiance Lo
	float NdotL = saturate(dot(N, L));

    return (kD * albedo / PI + specular) * radianceColor * NdotL;
}

float4 CalculateIrradianceMap(Texture2D cubemapTex, float3 normal)
{
	float4 irradiance = 0.0f;

	const float3 Nv = mul(normal, (float3x3)g_mWorldToView);				// normal, view-space
	const float sampleDelta = IRRADIANCE_SAMPLEDELTA;
	float nSamples = 0.0;
	for(float phi = 0.0; phi < 2.0 * PI; phi += sampleDelta)
	{
		for(float theta = 0.0; theta < 0.5 * PI; theta += sampleDelta)
		{
			float3 tangentSample = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));

			float2 uv = 0.0;
			uv.x = 0.5 * tangentSample.x * Nv.x + 0.5;
			uv.y = -0.5 * tangentSample.z * Nv.y + 0.5;

			irradiance += cubemapTex.Sample(pbr_TextureClampSampler, uv) * cos(theta) * sin(theta);
			nSamples++;
		}
	}
	irradiance = PI * irradiance * (1.0 / float(nSamples));

    return irradiance;
}

float3 CalculateBumpNormal(float3 norm_w, float3 pos_w, float2 uv, float3 normalTexColor, float bumpAmount)
{
    const float3 N0 = normalize(norm_w);
    const float3x3 tangentFrame = compute_tangent_frame(N0, pos_w, uv);

    float3 Nt = lerp(float3(0.0,0.0,1.0), normalTexColor, bumpAmount);
    float3 normal = normalize(mul(Nt, tangentFrame));

    return normal;
}

float4 Pbr(PS_INPUT input, float3 normal : NORMAL, float4 albedo : COLOR, float4 irradiance, float3 specularColor, float metallic, float roughness)
{
	// Degamma diffuse texture
	albedo = pow(albedo, 2.2);

	float3 V = -normalize(input.pos_w.xyz);
	
	float3 F0 = 0.04;
    F0 = lerp(F0, albedo, metallic);
	
	float3 Lo = float3(0.0, 0.0, 0.0);
	
	// Sun lighting
	float3 sunPos = input.pos_w.xyz - g_DirLight.dir;
	Lo += CalculateLightReflectance(sunPos, g_DirLight.color, input.pos_w.xyz, F0, normal, albedo, roughness, metallic);

    // Point lights
    [unroll(8)]
	for (int i = 0; i < g_NumPointLights; i++)
	{
		float3 radiance = CalculatePointLightRadiance(g_aPointLights[i].color, g_aPointLights[i].pos, input.pos_w.xyz, 
														g_aPointLights[i].invRange, g_aPointLights[i].Range2);
		
		Lo += CalculateLightReflectance(g_aPointLights[i].pos, radiance, input.pos_w.xyz, F0, normal, albedo, roughness, metallic);
	}

	// Spot lights
    [unroll(8)]
	for (int i = 0; i < g_NumSpotLights; i++)
	{
		float3 radiance = CalculateSpotLightRadiance(g_aSpotLights[i].color, g_aSpotLights[i].pos, input.pos_w.xyz, 
														g_aSpotLights[i].invRange, g_aSpotLights[i].Range2,
														g_aSpotLights[i].invRange, g_aSpotLights[i].angles);
		
		Lo += CalculateLightReflectance(g_aPointLights[i].pos, radiance, input.pos_w.xyz, F0, normal, albedo, roughness, metallic);
	}
	
    float vdotN = saturate(dot(normal, V));
    float3 F = fresnelSchlickRoughness(vdotN, F0, roughness);
    // float3 F = a0r(roughness, vdotN);

    // Ambient lighting via irradiance
    float3 kD = 1.0 - F;
    kD *= 1.0 - metallic;

    float3 diffuse = irradiance * albedo;

    // IBF calculations
    float3 prefilteredColor = specularColor; // TODO: mipmap envmap
    float2 envBRDF = EnvironmentBRDF(roughness, vdotN);
    float3 specular = envBRDF.x + prefilteredColor * (F * (envBRDF.y - envBRDF.x));
    
    float3 ambient = kD * diffuse + specular;

    // Finalize
	float4 color = float4(ambient, albedo.a) + float4(Lo, albedo.a);  // TODO: fix specular alpha?
    
    // Tonemap HDR and gamma
	color = color / (color + 1.0);
	color = pow(color, 1.0/2.2);
		
	return color;
}

float4 Pbr(PS_INPUT input, float3 normal : NORMAL, float4 albedo : COLOR, float4 irradiance, float metallic, float roughness)
{
    return Pbr(input, normal, albedo, irradiance, irradiance, metallic, roughness);
}

float4 Pbr(PS_INPUT input, float3 normal : NORMAL, float4 albedo : COLOR, float metallic, float roughness)
{
	// Calculate fake irradiance map
	float worldNDot = dot(normal, float3(0.0, 0.0, 1.0)) + 0.7;
    float sunNDot = dot(normal, -g_DirLight.dir);

	float sunLightCurve = smoothstep(0.2, 1.0, sunNDot);

	float3 ambLight = lerp(g_AmbientLight * 0.5, g_AmbientLight, worldNDot);
    float3 sunLight = lerp(0, g_DirLight.color, sunLightCurve);
    float3 irrad = saturate(ambLight + sunLight);
	
    return Pbr(input, normal, albedo, float4(irrad, 1), metallic, roughness);
}