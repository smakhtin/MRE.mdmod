//@author: vvvv group
//@help: this is a very basic template. use it to start writing your own effects. if you want effects with lighting start from one of the GouraudXXXX or PhongXXXX effects
//@tags:
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

// transforms
float4x4 tWVP: WORLDVIEWPROJECTION ;

//texture
texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 Pos  : POSITION ;
    float2 TexCd : TEXCOORD0 ;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(
    float4 PosO  : POSITION ,
    float4 TexCd : TEXCOORD0 )
{
    //declare output struct
    vs2ps Out;

    Out.Pos = mul(PosO, tWVP);
    Out.TexCd = TexCd;
	
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4 PS(vs2ps In): COLOR
{
	float4 col = tex2D(Samp, In.TexCd);
	float luma = (col.r*0.2125) + (col.g*0.7154) + (col.b*0.0721);
    return luma;
}

float4 PS_Log(vs2ps In): COLOR
{
	float4 col = tex2D(Samp, In.TexCd);
	float luma = (col.r*0.2125) + (col.g*0.7154) + (col.b*0.0721);
    return log(max(0.00001,luma));
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique Luma
{
    pass P0
    {
        ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS();
    }
}

technique LogLuma
{
    pass P0
    {
        ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS_Log();
    }
}
