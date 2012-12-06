float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;

float blur <string uiname="Blur Amount";> =0.0250;
float bal  <string uiname="Brightness Balance";> =0.0000;
half2 offset[24] = {
         -0.4359, 0.1607, 0.1664, 0.5123, 0.3133, 0.3036,-0.1008, 0.4993,
         -0.3530, 0.1366, 0.3797, 0.2241, 0.1543,-0.3514, 0.1237, 0.4231,
          0.0219,-0.2624,-0.4057, 0.0491, 0.0495, 0.4009,-0.3441, 0.0879,
          0.0414, 0.1031, 0.5815,-0.0840, 0.4988,-0.2451, 0.0952, 0.2564,
         -0.3005,-0.3880,-0.1673, 0.0923, 0.0785,-0.5410,-0.2227,-0.0161,
          0.3025,-0.1511, 0.2928, 0.1136, 0.0747,-0.3719,-0.0444, 0.2673,
         };

texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};


texture ctTex <string uiname="Control Texture";>;
sampler ctSamp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (ctTex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 Pos : POSITION;
    float4 TexCd : TEXCOORD0;
};


// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------

vs2ps VS(
    float4 Pos : POSITION,
    float4 TexCd : TEXCOORD0)
{
    vs2ps Out = (vs2ps)0;
    Out.Pos = mul(Pos, tWVP);
    Out.TexCd = mul(TexCd, tTex);
    return Out;
}
// PIXELSHADERS:
//------------------------------------------------------------
float4 gauswhitespiral(vs2ps In): COLOR
{
  float4 col = tex2D(Samp, In.TexCd);
  float4 orig = col;
  float4 ctrl = tex2D(ctSamp, In.TexCd);
  
  col.rgb = 0;
    for (int i = 0; i<24; i++)
    {
      col.rgb += tex2D(Samp, In.TexCd + offset[i] * blur * ctrl.x).rgb/24;
    }
  return float4(col.rgb,1);
}
 //---------------------------------------------------------------------
// TECHNIQUES:
technique GaussianSpiralBlurWhite
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 gauswhitespiral();
    }
}