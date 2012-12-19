//@author: dottore
//@description: Draws a surface using the data position texture. shading by phong directional
//@tags: 3d surface
//@credits: 
// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD ;        //the models world matrix
float4x4 tV: VIEW ;         //view matrix as set via Renderer (EX9)
float4x4 tVP: VIEWPROJECTION ;
float4x4 tWV: WORLDVIEW ;
float4x4 tWVP: WORLDVIEWPROJECTION ;
float4x4 matVI: VIEWINVERSE ;
float4x4 worldIT: WorldInverseTranspose;
float4x4 preTr;

#include "phong.fxh"
float3 mainlPos <string uiname="Main Light Position";> = 0;

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;
float4x4 ptWVP <string uiname="Previus Frame WorldViewProj Transform";>;

#include "..\shadows.fxh"
float shadowsAmount = 0;

texture TexData <string uiname="Data Texture";>;
sampler SampData = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexData);          //apply a texture to the sampler
    MipFilter = none;         //sampler states
    MinFilter = none;
    MagFilter = none;
};
texture pTexData <string uiname="Previous Data Texture";>;
sampler pSampData = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (pTexData);          //apply a texture to the sampler
    MipFilter = none;         //sampler states
    MinFilter = none;
    MagFilter = none;
};
texture TexReset <string uiname="Reset Data Texture (VelocityCycle)";>;
sampler SampReset = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexReset);          //apply a texture to the sampler
    MipFilter = none;         //sampler states
    MinFilter = none;
    MagFilter = none;
};
texture TexVol <string uiname="Particle Volume Texture";>;
sampler SampVol = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexVol);          //apply a texture to the sampler
    MipFilter = Linear;         //sampler states
    MinFilter = Linear;
    MagFilter = Linear;
};
texture TexNorm <string uiname="Particle Normal Texture";>;
sampler SampNorm = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexNorm);          //apply a texture to the sampler
    MipFilter = Linear;         //sampler states
    MinFilter = Linear;
    MagFilter = Linear;
};


float velGain <string uiname="Velocity Gain";> = 1;
float3 mbcorr = float3(0.0039,-0.0075,-0.1);
float alphatest = 0.5;
float depth = 0;
float posDepth = 0.3;
float gi <string uiname="Global Illumination Intensity";> = 1;
float lifespan = 1;

// -----------------------------------------------------------------------------
// MISC:
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// STRUCT:
// -----------------------------------------------------------------------------
struct appdata
{
    float4 PosO: POSITION;
    float3 NormO: NORMAL;
    float4 TexCdP: TEXCOORD0;
    float2 TexCdO: TEXCOORD1;
    float3 tang: TANGENT;
    float3 bino: BINORMAL;
};

struct vs2ps2
{
    float4 PosWVPp: POSITION;
    float4 PosWVP: TEXCOORD0;
    float4 PosW: TEXCOORD1;
    float3 PosWV : TEXCOORD2;
    float3 NormWV: NORMAL;
    float3 NormW: TEXCOORD3;
    float3 ViewDirWV: TEXCOORD4;
	float2 TexCd: TEXCOORD5;
	float3 eyeVec: TEXCOORD6;
    float4 vel: TEXCOORD7;
	float4 PiD: COLOR0;
};

// -----------------------------------------------------------------------------
// VERTEXSHADERS:
// -----------------------------------------------------------------------------

// PLACE and DEFORM technique
vs2ps2 VS(appdata In)
{
    //inititalize all fields of output struct with 0
    vs2ps2 Out = (vs2ps2)0;
    float3 particlePosition = tex2Dlod(SampData, In.TexCdP).rgb;
    float3 pParticlePosition = tex2Dlod(pSampData, In.TexCdP).rgb;
	Out.PiD = In.TexCdP;
	
	Out.TexCd = mul(float4(In.TexCdO,0,1), tTex);
	
	float4 dispPos = mul(In.PosO, preTr) + float4(particlePosition, 0);
	float3 dispNorm = In.NormO;
	float4 pdispPos = mul(In.PosO, preTr) + float4(pParticlePosition, 0);

    Out.PosW = mul(dispPos, tW);
    Out.PosWV = mul(dispPos, tWV);
    Out.PosWVP = mul(dispPos, tWVP);
    Out.PosWVPp = mul(dispPos, tWVP);
	float3 npos = Out.PosWVP.xyz;
	float3 pnpos = mul(pdispPos, ptWVP).xyz;
	Out.vel.rgb = (npos - pnpos) * velGain + mbcorr;
	float rst = tex2Dlod(SampReset, In.TexCdP).a;
	if(rst!=0) Out.vel.rgb = 0;
	Out.vel.a = 1;

    //normal in view space
    Out.NormWV = normalize(mul(dispNorm, tWV));
    Out.NormW = normalize(mul(dispNorm, tW));
    
    float3x3 tangentMap = float3x3(In.tang, In.bino, dispNorm);
    tangentMap = mul(tangentMap, tW);
	float3 eyeVec = Out.PosW - matVI[3].xyz;	
	Out.eyeVec = mul(tangentMap, eyeVec);

	//Out.ViewDirV = -normalize(mul(Out.PosW, tWV));
    Out.ViewDirWV = -normalize(mul(dispPos, tWV));
	
    return Out;
}

// -----------------------------------------------------------------------------
// MRT STRUCT:
// -----------------------------------------------------------------------------
struct col
{
    float4 color : COLOR0 ;
    float4 space : COLOR1 ;
    float4 normal : COLOR2 ;
    float4 vel : COLOR3 ;
};


// -----------------------------------------------------------------------------
// PIXELSHADERS:
// -----------------------------------------------------------------------------

col PS1(vs2ps2 In): COLOR
{
    col c;
	float3 uvb = float3(In.TexCd.xy, tex2D(SampVol, In.TexCd.xy).r);
	float3 normb = In.NormWV;
	if(depth!=0) normb += ((2 * (tex2D(SampNorm,uvb.xy))) - 1.0)*-depth;
	float3 normWb = In.NormW;
	float3 posWb = In.PosW;
	if(depth!=0) posWb += In.NormW * uvb.z * (-1*pow(depth,.5)) * posDepth;
	float3 posb = In.PosWV;
	if(depth!=0) posb += In.NormWV * uvb.z * (-1*pow(depth,.5)) * posDepth;
	float3 ViewDirWV = -normalize(posb);
	float shad = 1;
	if(shadowsAmount!=0) shad = lerp(1, softShadows(posWb, In.PosWVP, mainlPos).shadow, shadowsAmount);
	
	float alphat = 1;
	float alphatt = tex2D(diffSamp, uvb.xy).a * lDiff.a;
	alphat = alphatt;
	if(alphatest!=0) alphat = lerp(alphatt, (alphatt>=alphatest), min(alphatest*10,1));
	alphat *= tex2D(SampData, In.PiD).a/lifespan;

	c.color.rgb = PhongPoint(
		In.PosW,
		normb,
		ViewDirWV,
		shad,
		uvb.xy
	);

	//POSITION
    c.space.xyz = In.PosWV;
	if(depth!=0) c.space.xyz += posb*.1;
    c.space.w = alphat;
	
	c.color.a = alphat;
    
    //NORMALS
    float3 norm = normb;
    c.normal = float4(norm, gi*alphat);
	
	c.vel = In.vel;
	c.vel.a = alphat;

    return c;
}

// -----------------------------------------------------------------------------
// TECHNIQUES:
// -----------------------------------------------------------------------------

technique Phong_PointLight
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS1();
    }
}