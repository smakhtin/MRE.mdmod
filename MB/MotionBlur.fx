// this is a very basic template. use it to start writing your own effects.
// if you want effects with lighting start from one of the GouraudXXXX or PhongXXXX effects

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;
float4x4 tWVP: WORLDVIEWPROJECTION;

texture velmap <string uiname="Velocity map";>;
sampler VMSamp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (velmap);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

texture scene <string uiname="Original scene";>;
sampler ScnSamp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (scene);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

float4x4 tVmap: TEXTUREMATRIX <string uiname="Velocity map Transform";>;

float4x4 tOscn: TEXTUREMATRIX <string uiname="Original scene Transform";>;

float blurV <string uiname="Blur amount";> = 1;
float fov;
float offset;
float3 corr;
const int samples = 16;

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 Pos  : POSITION;
    float4 VmCd : TEXCOORD0;
    float4 OsCd : TEXCOORD1;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(
    float4 PosO  : POSITION,
    float4 VmCd : TEXCOORD0)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.Pos.xyz = PosO.xyz*2;
    Out.Pos.w = 1;
    
    //transform texturecoordinates
    Out.VmCd = mul(VmCd, tVmap);

    //transform the mask texture cordinates
    Out.OsCd = mul(VmCd, tOscn);
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------
float4 mblur(vs2ps In):Color
{
    float4 outColor = { 0.0, 0.0, 0.0, 1.00000 };
    float4 vmap = tex2D(VMSamp, In.VmCd);
    float4 oscn = tex2D(ScnSamp, In.OsCd);
    float4 vel = vmap*blurV;
    float dir = atan2(vel.y,vel.x)*-1;
	float vdis = length(vel.xy);
	vel.x = cos(dir)*vdis;
	vel.y = sin(dir)*vdis;
	vel.x += corr.x;
	vel.y += corr.y;
	vel.z += corr.z;
    vel *= (1-abs(fov-.5)*3)*1.5; //some correction
    
    if ((fov!=0) && (abs(fov)!=0.5)) {
    	vel.x -= (vel.z * (In.VmCd.x*2-1)) * (0.25/abs(fov-0.5));
    	vel.y -= (vel.z * (In.VmCd.y*2-1)) * (0.25/abs(fov-0.5));
    }
    //float4 temp = vel; //return for debugging
	float4 toscd = In.OsCd + vel/(samples/2)*(1+samples/4+offset);
	float4 Coscn = 0;
	for (int i = 0; i < samples; i++) {
    	toscd += -vel/samples;
    	Coscn = tex2D(ScnSamp, toscd);
		oscn += Coscn;
	}
    outColor = oscn/(samples+1);
	outColor.a = 1;
    return outColor;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique motion_blur
{
    pass  P0
    {
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 mblur();
    }
}