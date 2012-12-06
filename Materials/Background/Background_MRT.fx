//@author: m4d
//@help: deferred cubemap shader
//@tags: deferred, cubemap
//@credits: dottore & m4d

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 tWV: WORLDVIEW;

//material properties
float4 cAmb : COLOR <String uiname="Color";>  = {1, 1, 1, 1};
//float gi <String uiname="Global Illumination Value";> = 1;
float cubeMult;
float cubeMapExp;
float velGain <string uiname="Velocity Gain";> = 1;
float4x4 ptWVP <string uiname="Previus Frame WorldViewProj Transform";>;
float3 mbcorr = float3(0.0039,-0.0075,-0.1);

//texture
texture texCubeMap <string uiname="CubeMap";>;
sampler SampTex = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (texCubeMap);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//texture transformation marked with semantic TEXTUREMATRIX to achieve symmetric transformations
float4x4 tTex: CUBETEXTUREMATRIX <string uiname="Texture Transform";>;

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 position  : POSITION ;
    float3 uv : TEXCOORD0 ;
    float3 camera_position : TEXCOORD1 ;
    float3 camera_normal   : TEXCOORD2 ;
	float4 vel : TEXCOORD3 ;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(
    float4 PosO  : POSITION ,
    float3 normal : NORMAL ,
    float4 TexCd : TEXCOORD )
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.position = mul(PosO, tWVP);
	float3 npos = Out.position.xyz;
	float3 pnpos = mul(PosO, ptWVP).xyz;
	Out.vel.rgb = (npos - pnpos) * velGain + mbcorr;
	Out.vel.a = 1;
    
    //transform texturecoordinates
    Out.uv = PosO;

    Out.camera_position = mul(PosO, tWV);

    Out.camera_normal = normalize(mul(normal, tWV));
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
	float4 vel : COLOR3 ;
};

col PS(vs2ps In) 
{
	col c = (col)0;
    c.c1 = cAmb * lerp(1,texCUBE(SampTex, In.uv),cubeMult) * cubeMapExp;

    c.c2.xyz = In.camera_position;
    c.c2.w   = 1.0f;

    //norm.z *= 1.0;
    c.c3 = float4(normalize(In.camera_normal), 0);
	
    return c;
}

col PSflat(vs2ps In)
{
	col c;
	c.c1 = cAmb;
	
	c.c2.xyz = In.camera_position;
	c.c2.w   = 1.0f;
	
	c.c3 = float4(normalize(In.camera_normal),0);
	c.vel = In.vel;
	c.vel.a = 1;
	
	return c;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique CubeMap
{
    pass MRT
    {
    	ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS();
    }
}

technique Flat
{
	pass MRT
	{
    	ALPHABLENDENABLE = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader =  compile ps_3_0 PSflat();
	}
}
