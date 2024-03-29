//@author: vvvv group
//@help: draws a mesh with a constant color
//@tags: template, basic
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;

//material properties
float2 pick = 0;
float2 area = 0;
float alpha = 1;
float focus = 0;
float epsilon = 0.01;
#define SAMPLES 36
#define SQRTSAMP 6

//texture
texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;

//the data structure: vertexshader to pixelshader
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
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.Pos = mul(Pos, tWVP);

    //transform texturecoordinates
    Out.TexCd = mul(TexCd, tTex);

    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4 PS(vs2ps In): COLOR
{
    //In.TexCd = In.TexCd / In.TexCd.w; // for perpective texture projections (e.g. shadow maps) ps_2_0
	float2 colpick = pick/2+.5;
	float4 col = {0,0,0,0};
	if ((area.x==0)&&(area.y==0))
	{
    	col = tex2D(Samp, colpick);
		if(abs(col.z)<epsilon) col.z=focus;
	}
	else
	{
		float2 offset = colpick-area/2;
		float4 tcol = float4(0,0,0,1);
		int ii = 0; int jj = 0;
		for (int i=0; i<SAMPLES; i++)
		{
			ii=i%SQRTSAMP; jj=floor(i/SQRTSAMP);
			tcol = tex2D(Samp,offset);
			if(abs(tcol.z)<epsilon) tcol.z=focus;
			col += tcol/SAMPLES;
			offset.x += 1/SQRTSAMP*area.x;
			if(ii==0) offset.x = colpick.x-area.x/2;
			offset.y += (ii==0) ? (1/SQRTSAMP*area.y) : 0;
		}
	}
	return float4(col.rgb,alpha);
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TConstant
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PS();
    }
}