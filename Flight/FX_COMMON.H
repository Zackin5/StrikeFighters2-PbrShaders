
#ifndef FX_COMMON
#define FX_COMMON

float4 SampleChromaticAberration(Texture2D sourceTex, SamplerState sourceSample, float2 uv, float2 caUv, float caStrength)
{
	float4 baseColor = sourceTex.Sample(sourceSample, uv);

    if(caStrength <= 0)
        return baseColor;

    float4 caColor = float4(0,0,0,0);
    caColor.r = sourceTex.Sample(sourceSample, uv, +caUv).r;
    caColor.g = sourceTex.Sample(sourceSample, uv).g;
    caColor.b = sourceTex.Sample(sourceSample, uv, -caUv).b;

    caColor.a = (sourceTex.Sample(sourceSample, uv, +caUv).a
                + sourceTex.Sample(sourceSample, uv).a
                + sourceTex.Sample(sourceSample, uv, -caUv).a) 
                / 3.0;

	return lerp(baseColor, caColor, caStrength);
}

#endif