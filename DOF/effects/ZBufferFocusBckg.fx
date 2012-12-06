// this is a very basic template. use it to start writing your own effects.
// if you want effects with lighting start from one of the GouraudXXXX or PhongXXXX effects

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------
float4x4 tWVP: WORLDVIEWPROJECTION;
texture tex0;
sampler s0=sampler_state{Texture=(tex0);MipFilter=LINEAR;MinFilter=LINEAR;MagFilter=LINEAR;};
struct vs2ps
{
   float4 Pos: POSITION;
   float2 TexCd: TEXCOORD0;
};
float focus = 0;
float2 dof = float2(0.1, 0.4);

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS_ZBuffer(
	float4 Pos: POSITION,
	float2 TxCd: TEXCOORD0)
{
   vs2ps Out = (vs2ps) 0;
   Out.Pos = mul(Pos, tWVP);
   Out.TexCd = TxCd;
   
   return Out;
}


// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------
struct colout {
	float4 frg : COLOR;
	float4 bckg : COLOR1;
};
float4 dofPS(vs2ps In): COLOR
{
	float3 ppos = tex2D(s0, In.TexCd).xyz;
    float bckg0 = abs(ppos.z-focus);
	bckg0 *= ((ppos.z-focus)<0) ? dof.y : dof.x;
    float frg0 = max(-1*(ppos.z-focus),0);
	frg0 *= ((ppos.z-focus)<0) ? dof.y : dof.x;
	/*
	if(!(ppos.z==0)) return float4(bckg0.xxx, 1);
	else return float4(0,0,0,1);*/
	return float4(bckg0.xxx, 1);
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique AllInOne
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_ZBuffer();
        PixelShader  = compile ps_3_0 dofPS();
    }
}
