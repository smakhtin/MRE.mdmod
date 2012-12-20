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

float MotionBlurMult = 1;
float3 mbcorr = float3(0.0039,-0.0075,-0.1);

float2 ViewportSize;
float4x4 PreviousTransformWV;

float FakeVelocity = 1;

texture TranslateScaleTex <string uiname="TranslateXYZ (XYZ), UniformScale (W)";>;
sampler TranslateScaleSamp = sampler_state
{
    Texture   = (TranslateScaleTex);          
    MipFilter = LINEAR;                    
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

texture PreviousTranslateScaleTex <string uiname="Previous TranslateXYZ (XYZ), UniformScale (W)";>;
sampler PreviousTranslateScaleSamp = sampler_state
{
    Texture   = (PreviousTranslateScaleTex);          
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
    float4 PosWV : TEXCOORD2;
	float4 PosWVP: POSITION;
    float4 NormWV : NORMAL;
    float4 Vel : COLOR7;
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
	float4 pTransform = 0;
    
    float4 particleTransform = tex2Dlod(TranslateScaleSamp, TransformTexCd);
	float4 previousParticleTransform = tex2Dlod(PreviousTranslateScaleSamp, TransformTexCd);
    
	pTransform.w = Pos.w;
	pTransform.xyz = Pos.xyz + particleTransform.xyz;
	
    Pos.xyz  += particleTransform.xyz;
    
    Out.PosWV = mul(Pos, tWV);
	Out.PosWVP = mul(Pos, tWVP);
	
	pTransform = mul(pTransform, PreviousTransformWV);
	
	//Out.Vel.xyz = 0 * MotionBlurMult + mbcorr;
	Out.Vel.xyz = (Out.PosWV.xyz - pTransform.xyz) * MotionBlurMult + mbcorr;
	Out.Vel.w = 1;
    
    Out.TextureTexCd = TextureTexCd;

    Out.NormWV = normalize(mul(NormO, tWV));
	
	float size = min(ViewportSize.x, ViewportSize.y);
	
	float projScaleMax  = max(tP[0][0], tP[1][1]);
	
	//Detecting empty VIEW and PROJECTION matrixes (no camera)
	if(abs(tV[0][0] - tP[0][0]) < 0.001 || abs(tV[1][1] - tP[1][1]) < 0.001)
	{
		projScaleMax /=	2;
	}
	
	Out.Size = (size / 2) * (projScaleMax / Out.PosWV.z) * particleTransform.w;
    
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
	output Out = (output)0;
	
	Out.color = tex2D(Samp, In.TextureTexCd) * Color;
	Out.space = In.PosWV;
	Out.normal = In.NormWV;

	Out.velocity = In.Vel;

    return Out;
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
