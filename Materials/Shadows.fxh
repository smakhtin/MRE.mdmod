float bias <string uiname="Shadow Bias";> = 0.02;
float contrast <string uiname="Contrast";> = 5;
const int samples <string uiname="Samples";> = 3;
float softness <string uiname="Softness";> = 0;
float blurring <string uiname="Softness Distance Multiplier";> = 1;
float noiseAmount = 0;
float epsilon = 0.05;

//texture
texture TexMap <string uiname="ShadowMap";>;
samplerCUBE smap = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexMap);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};
texture loTx <string uiname="Light Offset";>;
sampler lightOffset = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (loTx);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};
texture nTx <string uiname="Noise";>;
sampler noiseSamp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (nTx);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

struct shadowdata
{
	float shadow;
	float difference;
};

shadowdata softShadows(float3 wPos, float3 wvpPos, float3 LightPos)
{
    //In.TexCd = In.TexCd / In.TexCd.w; // for perpective texture projections (e.g. shadow maps) ps_2_0
	shadowdata col = (shadowdata)0;

	float3 pp1 = wPos;
	float3 pp2 = pp1 - LightPos;
	float pdist1 = texCUBE(smap, normalize(pp2)).x;
    float pdist2 = length(pp2);
	float dd = pdist2 - pdist1;
	col.difference = dd;

	col.shadow = 1;
	for(float i=0; i<samples; i++) {
		float3 offs = tex2D(lightOffset, float2(i/samples, 0.5)).rgb;
		float3 noise = 0;
		if(noiseAmount!=0) noise = (tex2D(noiseSamp, float2(wvpPos.x + (i/samples)*.05, wvpPos.y)).rgb-0.5) * noiseAmount*(pdist2*blurring*6);
		float3 p1 = wPos + offs * (pdist2*blurring) + noise;
		float3 p2 = p1 - LightPos;
		float dist1 = texCUBE(smap, normalize(p2)).z;
    	float dist2 = length(p2);
		//float tmp = ((dist2-bias) > dist1);
		float tmp = min(max((dist2-dist1)/contrast-bias,0),1);
		col.shadow -= tmp/samples;
	}

    return col;
}