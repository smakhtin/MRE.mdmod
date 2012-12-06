//    light properties
//    data texture format:
// r1 Pos+range
// r2 color+strength

texture lTex <String uiname="Light Data";>;
sampler lSamp = sampler_state
{
    Texture   = (lTex);          //apply a texture to the sampler
    MipFilter = POINT;         //sampler states
    MinFilter = POINT;
    MagFilter = POINT;
};
const int lsamples <String uiname="Light Count"; int uimin=1;> = 1;
const int lindex <String uiname="Main Light Index"; int uimin=0;> = 0;

float lAtt0 <String uiname="Light Attenuation 0"; float uimin=0.0;> = 0;
float lAtt1 <String uiname="Light Attenuation 1"; float uimin=0.0;> = 0.3;
float lAtt2 <String uiname="Light Attenuation 2"; float uimin=0.0;> = 0;
float lPower <String uiname="Power"; float uimin=0.0;> = 25.0;     //shininess of specular highlight

float4 lAmb  : COLOR <String uiname="Ambient Color";>  = {0.15, 0.15, 0.15, 1};
float4 lEm  : COLOR <String uiname="Emission Color";>  = {0, 0, 0, 1};
texture emTex <String uiname="Emission Texture";>;
sampler emSamp = sampler_state
{
    Texture   = (emTex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};
float4 lDiff : COLOR <String uiname="Object Color";>  = {0.85, 0.85, 0.85, 1};
float diffAmount <String uiname="Diffuse Amount";> = 1;
texture diffTex <String uiname="Diffuse Texture";>;
sampler diffSamp = sampler_state
{
    Texture   = (diffTex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};
float4 lSpec : COLOR <String uiname="Specular Color";> = {0.35, 0.35, 0.35, 1};
float specAmount <String uiname="Specular Amount";> = 1;
texture specMap <String uiname="Specular Map";>;
sampler specSamp = sampler_state
{
    Texture   = (specMap);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};
bool shadeAll <String uiname="Shade all lights";> = 0;

//phong point function
float3 PhongPoint(float3 PosW, float3 NormV, float3 ViewDirV, float shadow, float2 TexCd)
{
    float3 outCol = 0;
    for(float i=0; i<lsamples; i++)
    {
        float index = i/lsamples;
        float4 lDat1 = tex2D(lSamp, float2(i/lsamples, .25));
        float4 lDat2 = tex2D(lSamp, float2(i/lsamples, .75));

        float3 lPos = lDat1.xyz;
        float lRange = lDat1.w;
        float3 lCol = lDat2.xyz * lDat2.w;

        float d = distance(PosW, lPos);
        float atten = 0;
        float3 amb=0;
        float3 diff = 0;
        float3 spec = 0;
        float specmap = tex2D(specSamp, TexCd).r;

        if((d<lRange) && (!(((i==lindex) || shadeAll) && (shadow==0))))
        {
            atten = 1/(saturate(lAtt0) + saturate(lAtt1) * d + saturate(lAtt2) * pow(d, 2));
            amb = lAmb.rgb * atten;

            float3 LightDirW = normalize(lPos - PosW);
            float3 LightDirV = mul(LightDirW, tV);

            //halfvector
            float3 H = normalize(ViewDirV + LightDirV);
            //compute blinn lighting
            float3 shades = lit(dot(NormV, LightDirV), dot(NormV, H), lPower);
            diff = lDiff.rgb * lCol * shades.y * atten;
            //reflection vector (view space)
            float3 R = normalize(2 * dot(NormV, LightDirV) * NormV - LightDirV);
            //normalized view direction (view space)
            float3 V = normalize(ViewDirV);
            //calculate specular light
            spec = pow(max(dot(R, V),0), lPower*.2) * lSpec.rgb * lCol;
        }
        outCol += ((amb/lsamples) + diff * diffAmount) + spec * specAmount * specmap;
        if((i==lindex) || shadeAll) outCol *= shadow;
    }
    outCol *= tex2D(diffSamp, TexCd).rgb;
    outCol += lEm.rgb * tex2D(emSamp, TexCd).rgb;
    return outCol;
}