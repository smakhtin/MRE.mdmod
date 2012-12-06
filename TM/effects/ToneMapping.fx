//@author: dottore
//@help: this shader apply tone mappping to the hdr source map using luminance texture
//@tags: tone mapping hdr
//@credits: vux, m4d

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD ;        //the models world matrix
float4x4 tV: VIEW ;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION ;
float4x4 tWVP: WORLDVIEWPROJECTION ;

//texture
texture tex <string uiname="Texture";>;
sampler samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (tex);          //apply a texture to the sampler
    MipFilter = none;         //sampler states
    MinFilter = none;
    MagFilter = none;
};
texture tex2 <string uiname="avgLumaTexture";>;
sampler samp2 = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (tex2);          //apply a texture to the sampler
    MipFilter = none;         //sampler states
    MinFilter = none;
    MagFilter = none;
};

// GAMMA CORRECTION:
float invGamma;

// TONEMAPPING:
float tonemapCurve[8];
#define shoulderStrength tonemapCurve[0]
#define linearStrength tonemapCurve[1]
#define linearAngle tonemapCurve[2]
#define toeStrength tonemapCurve[3]
#define toeNumerator tonemapCurve[4]
#define toeDenominator tonemapCurve[5]
#define linearWhitePointValue tonemapCurve[6]
#define exposureBias tonemapCurve[7]

float KeyA;
float maxAvgLuma = 1;

// VIGNETTE:
bool EnableVignette = 1;
float vgnBlend <String uiname="Vignette Transparency";> = 1;
float vgnPow <String uiname="Vignette Power";> = 1;
float vgnMin <String uiname="Vignette MInimum Distance";> = 0;
float vgnMax <String uiname="Vignette Maximum Distance";> = 1;

// COLOR CORRECTION:
bool EnableColCorrection = 0;
float4x4 tCol <string uiname="Color Transform";>;

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
    //transform position
    Out.Pos = mul(PosO, tWVP);  
    //transform texturecoordinates
    Out.TexCd = TexCd;   
    return Out;
}



// --------------------------------------------------------------------------------------------------
// FUNCTIONS:
// --------------------------------------------------------------------------------------------------

float3 Uncharted2Tonemap(float3 x)
{
   return ((x*(shoulderStrength*x+linearAngle*linearStrength)+toeStrength*toeNumerator)/(x*(shoulderStrength*x+linearStrength)+toeStrength*toeDenominator))-toeNumerator/toeDenominator;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4 PS(vs2ps In):COLOR
{
	float invAvgLuma = min(maxAvgLuma,max(0,1/(tex2D(samp2,float2(.5,.5)).r)));
    // get avarage Lw from the texture we calculate previously
    float aOverBarLw = KeyA * invAvgLuma;

   float3 texColor = tex2D(samp, In.TexCd );
   texColor *= aOverBarLw;//16;  // Hardcoded Exposure Adjustment

   float3 curr = Uncharted2Tonemap(exposureBias*texColor);

   float3 whiteScale = 1.0f/Uncharted2Tonemap(linearWhitePointValue);
   float3 color = curr*whiteScale;

   float3 retColor = pow(color,invGamma);
	
	// COLOR CORRECTION:
	if(EnableColCorrection)
	{	retColor = mul(retColor, tCol);	}

	// VIGNETTE:
	if(EnableVignette)
	{
	float distCenter = pow(saturate(smoothstep(vgnMax,vgnMin,distance(In.TexCd.xy, float2(.5,.5)))), vgnPow);
    distCenter = lerp(vgnBlend, 1, distCenter); 
    retColor.rgb *= distCenter;	
	}

   return float4(retColor,1);
}
// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique Tonemapping
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS();
    }
}
