//@author: dottore
//@help: MRT passes = renders diffuse with constant technique, position, normal
//@tags: MRT
//@credits: 

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tWVP: WORLDVIEWPROJECTION ;
float4x4 tWV: WORLDVIEW ;

//material properties
float4 cAmb : COLOR <String uiname="Color";>  = {1, 1, 1, 1};
float GI <String uiname="Gi amount";> = 1;	// amount of ambient occlusion and cubemap illumination

//texture
texture Tex <string uiname="Texture";>;
sampler SampTex = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//texture transformation marked with semantic TEXTUREMATRIX to achieve symmetric transformations
float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;
float4x4 ptWVP <string uiname="Previus Frame WorldViewProj Transform";>;
float velGain <string uiname="Velocity Gain";> = 1;
float3 mbcorr = float3(0.0039,-0.0075,-0.1);

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 position  : POSITION ;
    float2 TexCd : TEXCOORD0 ;
    float3 PosWV : TEXCOORD1 ;
    float3 NormWV   : TEXCOORD2 ;
    float4 vel : COLOR0 ;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(
    float4 PosO  : POSITION ,
    float3 NormO : NORMAL0 ,
    float4 TexCdO : TEXCOORD0 )
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.position = mul(PosO, tWVP);
	float3 npos = Out.position.xyz;
	float3 pnpos = mul(PosO, ptWVP).xyz;
	Out.vel.rgb = ((npos - pnpos) * velGain + mbcorr);
	Out.vel.a = 1;
    
    //transform texturecoordinates
    Out.TexCd = mul(TexCdO, tTex);
    
    Out.PosWV = mul(PosO, tWV);

    Out.NormWV = mul(NormO, tWV);
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

struct col
{
    float4 c1 : COLOR0 ;
    float4 c2 : COLOR1 ;
    float4 c3 : COLOR2 ;
    float4 c4 : COLOR3 ;
};

col PS(vs2ps In)
{
    col c;

    c.c1 = cAmb * tex2D(SampTex, In.TexCd);

    c.c2.xyz = In.PosWV;
    c.c2.w   = 1.0f;

    c.c3 = float4(normalize(In.NormWV),GI);
	c.c4 = In.vel;
	c.c4.a = 1;

    return c;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TSimpleShader
{
    pass SSAO_FillFront
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
    	//ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS();
    }
}
