//@author: alg
//@description: Draws a Constant ParticlesGPU Sprites mesh using the data texture (Compatible with MRE mdmod)
//@tags: particles sprites
//@credits: dottore, Viktor Vicsek for Sprites Function

float4x4 tW: WORLD;
float4x4 tV: VIEW;
float4x4 tP: PROJECTION;
float4x4 tVP: VIEWPROJECTION;
float4x4 tWV: WORLDVIEW;
float4x4 tWVP: WORLDVIEWPROJECTION;

float2 ViewportSize;

texture TranslateScaleTex <string uiname="TranslateXYZ (XYZ), UniformScale (W)";>;
sampler TranslateScaleSamp = sampler_state
{
    Texture   = (TranslateScaleTex);          
    MipFilter = LINEAR;                    
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

texture Texture <string uiname="Texture";>;
sampler Samp = sampler_state
{
    Texture   = (Texture);          
    MipFilter = LINEAR;        
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

float4 Color :COLOR = 1;

struct vs2ps
{
    float4 PosWV : POSITION;
    float4 NormWV : NORMAL;
    float4 Velocity : TEXCOORD7;
    float4 TextureTexCd : TEXCOORD1;
    float Size : PSIZE;
};


vs2ps VS(
    float4 Pos : POSITION ,
    float4 TransformTexCd : TEXCOORD0,
    float4 TextureTexCd : TEXCOORD1,
    float4 NormO : NORMAL)
{
    vs2ps Out = (vs2ps)0;
    
    float4 particleTransform = tex2Dlod(TranslateScaleSamp, TransformTexCd);
    
    Pos.xyz  += particleTransform.xyz;
    
    Out.PosWV = mul(Pos, tWV);
    
    Out.TextureTexCd = TextureTexCd;

    Out.NormWV = normalize(mul(In.NormO, tWV));
	
	float size = min(ViewportSize.x, ViewportSize.y);
	
	float projScaleMax  = max(tP[0][0], tP[1][1]);
	
	//Detecting empty VIEW and PROJECTION matrixes (no camera)
	if(abs(tV[0][0] - tP[0][0]) < 0.001 || abs(tV[1][1] - tP[1][1]) < 0.001)
	{
		projScaleMax /=	2;
	}
	
	Out.Size = (size / 2) * (projScaleMax / Out.Pos.z) * particleTransform.w;
    
	return Out;
}

// -----------------------------------------------------------------------------
// MRT STRUCT:
// -----------------------------------------------------------------------------
struct output
{
    float4 color : COLOR0 ;
    float4 space : COLOR1 ;
    float4 normal : COLOR2 ;
    float4 velocity : COLOR3 ;
};

output MAIN_PS(vs2ps In): COLOR
{
	output out = (output)0;
	
	out.color = tex2D(Samp, In.TextureTexCd) * Color;
	out.space = In.PosWV;
	out.normal = In.NormWV;

	out.velocity = 1;

    return tex2D(Samp, In.TextureTexCd) * Color;
}

technique Main
{
	pass P0
    {
		FillMode = POINT;
		PointScaleEnable = true;
		PointSpriteEnable = true;
		
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 MAIN_PS();
	}
}
