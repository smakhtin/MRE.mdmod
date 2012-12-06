//@author: vux
//@help: deffered version for fog
//@tags: directx,deferred
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tWVP: WORLDVIEWPROJECTION ;

float fogstart = 0;
float FogDensity = 10;
float4 FogColor : COLOR =(0.4,0.2,0.2,1.0);
float4 SunColor : COLOR;


float FogMaxY = 0;
float FogYRange = 3;
float3 sunDirection;
float sunStrength = 1.0f;
float sunPower = 2;

float4x4 tInverseView;


//texture
texture TexSrc <string uiname="Texture Source";>;
sampler SampSrc = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexSrc);          //apply a texture to the sampler
    MipFilter = POINT;         //sampler states
    MinFilter = POINT;
    MagFilter = POINT;
};

//texture
texture TexPos <string uiname="Texture Position";>;
sampler SampPos = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexPos);          //apply a texture to the sampler
    MipFilter = POINT;         //sampler states
    MinFilter = POINT;
    MagFilter = POINT;
};

struct vs2ps
{
    float4 Pos : POSITION  ;
    float4 TexCd : TEXCOORD0 ;
};

vs2ps VS(
    float4 Pos : POSITION ,
    float4 TexCd : TEXCOORD0 )
{
    vs2ps Out = (vs2ps)0;
    Out.Pos = mul(Pos, tWVP);
    Out.TexCd = TexCd;
    return Out;
}

float4 PSimpleExp(float2 texCoord : TEXCOORD0) : COLOR0
{
	float4 color = tex2D(SampSrc, texCoord) ;
	float3 pos = tex2D(SampPos,texCoord);
		
	float d = distance(pos,0);
	d = max(d - fogstart,0);
		
	float fogamount = exp(-d * FogDensity * 0.1);
		
	color = lerp(FogColor,color,fogamount);
	return float4(color.rgb, 1);
}

float4 PExpHeight(float2 texCoord : TEXCOORD0) : COLOR0
{
   float4 color = tex2D(SampSrc, texCoord) ;
	float3 pos = tex2D(SampPos,texCoord);
	
	float d = distance(pos,0);
	d = max(d - fogstart,0);
	
	//Get world space position 
	float3 vp = mul(float4(pos,1),tInverseView);
	
	//Get a height based coeff
	float vpy =1.0f - saturate((vp.y - FogMaxY) / (FogMaxY +FogYRange) );
	
	d *= vpy;	
	float fogamount = exp(-d * FogDensity * 0.1);
	
	color = lerp(FogColor,color,fogamount);
   return float4(color.rgb, 1);
}

float4 PExpSun(float2 texCoord : TEXCOORD0) : COLOR0
{
	float4 color = tex2D(SampSrc, texCoord) ;
	float3 pos = tex2D(SampPos,texCoord);
	
	float d = distance(pos,0);
	d = max(d - fogstart,0);
		
	float fogAmount = 1.0f -exp ( -d *0.1f* FogDensity );
	float sunAmount = pow ( max ( dot ( pos, sunDirection ), 0.0f ), sunPower ) * sunStrength * 0.0001;
	//sunAmount = 1;
	float3 fogColor = lerp (FogColor.rgb,SunColor.rgb , sunAmount );
	return float4(lerp ( color.rgb, fogColor, fogAmount),1);
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TSimpleExp
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PSimpleExp();
    }
}

technique TExpHeight
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PExpHeight();
    }
}

technique TExpSun
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PExpSun();
    }
}




