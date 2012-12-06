//@author: m4d
//@help: interleaved SSAO - combinepass -- blurs the previous ssao pass and combines it with diffuse fill pass and additional cubemap lighting
//@tags: ssao, interleaved, combine, cubemap, lighting
//@credits: original shader by ArKano22 of gamedev.net -- see thread http://www.gamedev.net/community/forums/topic.asp?topic_id=556187&PageSize=25&WhichPage=1

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD ;        //the models world matrix
float4x4 tV: VIEW ;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION ;
float4x4 tWVP: WORLDVIEWPROJECTION ;
float4x4 tVI: VIEWINVERSE ;

//texture
texture TexSSAO <string uiname="Texture SSAO";>;
sampler SampSSAO = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexSSAO);          //apply a texture to the sampler
    MipFilter = none;         //sampler states
    MinFilter = none;
    MagFilter = none;
};

texture TexNorm <string uiname="Texture Normal";>;
sampler SampNorm = sampler_state   //sampler for doing the texture-lookup
{
    Texture   = (TexNorm);          //apply a texture to the sampler
    MipFilter = none;              //sampler states
    MinFilter = none;
    MagFilter = none;
};

texture TexCube <string uiname="Texture Cubemap";>;
sampler SampCube = sampler_state   //sampler for doing the texture-lookup
{
    Texture   = (TexCube);          //apply a texture to the sampler
    MipFilter = linear;              //sampler states
    MinFilter = linear;
    MagFilter = linear;
};

texture TexDiffuse <string uiname="Texture Diffuse";>;
sampler SampDiffuse = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexDiffuse);          //apply a texture to the sampler
    MipFilter = none;         //sampler states
    MinFilter = none;
    MagFilter = none;
};
float2 InvScreenSize <string uiname="Inverse Screen Size";> = 1;
float Blur <string uiname="Blur";> = 1;
float4x4 lightMatrix : MATRIX <string uiname="Inverse View";>;
float UseAO <string uiname="Enable AO";> = 1;
float UseCube <string uiname="Enable Cube Map";> = 1;
float cubemapMult = 1;

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 position  : POSITION0 ;
    float2 uv : TEXCOORD0 ;
	float3 uv2 : TEXCOORD1 ;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(
    float4 position  : POSITION ,
    float4 uv : TEXCOORD0 ,
	float3 uv2 : TEXCOORD1 )

{
    //declare output struct
    vs2ps Out;

    //transform position
	position.xy *= 2;
    Out.position = float4(mul(position, tWVP));
    
    //transform texturecoordinates
    Out.uv = uv;
	Out.uv2 = position;
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------
float4 getNormal(in float2 uv)
{
  float4 normData = tex2D(SampNorm,uv);
  normData.xyz = normalize(normData.xyz);
  return normData;
}

float4 PS_SSAO_Cubemap(vs2ps In): COLOR
{
  float4 o = (0.0,0.0,0.0,1.0);
  o = tex2D(SampDiffuse, In.uv);
  const float2 vec[3] = {
   float2(1,1),
   float2(1,0),
   float2(0,1),
   };

  float4 n = getNormal(In.uv);

  float3 ao = tex2D(SampSSAO,In.uv).xyz;
  int samples = 1;
  for (int k=0;k<3;k++){
     float2 tcoord = In.uv+float2(vec[k].x*InvScreenSize.x*Blur,vec[k].y*InvScreenSize.y*Blur);
     ao+=tex2D(SampSSAO,tcoord).xyz;
     samples++;
  }
  ao/=samples;

  if (UseAO)	o.rgb *= 1-(saturate(ao)*n.a);
  if (UseCube)	o.rgb *= lerp(1, texCUBE(SampCube, mul(n.xyz, lightMatrix))*cubemapMult,n.a);;

  return o;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique SSAO_CubemapLight
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS_SSAO_Cubemap();
    }
}
