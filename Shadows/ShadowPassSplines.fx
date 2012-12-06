//@author: vvvv group
//@help: draws a mesh with a constant color
//@tags: template, basic
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 matVI: VIEWINVERSE ;

#define NUM_ITERATIONS 16
#define NUM_ITERATIONS_RELIEF1 11
#define NUM_ITERATIONS_RELIEF2 5
#define minTwoPi -6.283185307179586476925286766559
#define TwoPi 6.283185307179586476925286766559


float3 LightPos <string uiname="Light Position";> = 0;

//texture
float4x4 TransformW <string uiname="Mesh Transform";>;
texture TexYResampSpl <string uiname="Y Resampled Texture (spline)";>;
sampler YResampSpl = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexYResampSpl);          //apply a texture to the sampler
    MipFilter = linear;         //sampler states
    MinFilter = linear;
    MagFilter = linear;
    AddressU = clamp;//mirror;
    AddressV = clamp;//mirror;
};
texture TexDirSpl <string uiname="Direction Texture";>;
sampler DirSpl = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexDirSpl);          //apply a texture to the sampler
    MipFilter = linear;         //sampler states
    MinFilter = linear;
    MagFilter = linear;
    AddressU = clamp;//mirror;
    AddressV = clamp;//mirror;
};
texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};
texture TexBump <string uiname="Bump Map";>;
sampler2D cone_map = sampler_state
{
	Texture = <TexBump>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
sampler3D sphere_map = sampler_state
{
	Texture = <TexBump>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
bool isPTxCd <string uiname="Position as Texture Coordinates";> = 0;
float depth = 0;
float posDepth = 0.3;
bool DEPTH_BIAS = false;
bool BORDER_CLAMP = false;
float3 size_source;

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;

float3 cone(float2 uv0, float3 eyeVec, sampler2D cone_map)
{
	float3 rayPos;
	float3 rayVec;
	rayPos = float3(uv0, 0.0);
	
	rayVec = normalize(eyeVec);
	rayVec.z = abs(rayVec.z);

	// DerayPosth bias used by Fabio rayPosolicarrayPoso
	if (DEPTH_BIAS)
	{
		float db = 1.0 - rayVec.z;
		db *= db;
		db = 1.0 - db*db;
		rayVec.xy *= db;
	}
	
	rayVec.xy *= depth;

	float dist = length(rayVec.xy);
	
	for( int i=0;i<NUM_ITERATIONS; i++ )
	{
		float4 tex = tex2D(cone_map, rayPos.xy);
		float height = saturate(tex.w - rayPos.z);

		float cone_ratio = tex.z*tex.z;
		float stepDist = height * cone_ratio / (cone_ratio + dist);
		rayPos += rayVec * stepDist;
		
	}
	
	return rayPos.xyz;
}
float4x4 Vrotate(float rotX, 
		 float rotY, 
		 float rotZ)
  {
   rotX *= TwoPi;
   rotY *= TwoPi;
   rotZ *= TwoPi;
   float sx = sin(rotX);
   float cx = cos(rotX);
   float sy = sin(rotY);
   float cy = cos(rotY);
   float sz = sin(rotZ);
   float cz = cos(rotZ);

   return float4x4( cz*cy+sz*sx*sy, sz*cx, cz*-sy+sz*sx*cy, 0,
                   -sz*cy+cz*sx*sy, cz*cx, sz*sy+cz*sx*cy , 0,
                    cx * sy       ,-sx   , cx * cy        , 0,
                    0             , 0    , 0              , 1);
  }
//the data structure: vertexshader to pixelshader
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 Pos : POSITION;
    float3 NormWV: NORMAL;
    float3 NormW: TEXCOORD2;
    float2 TexCd : TEXCOORD0;
    float4 wPos : TEXCOORD1;
	float3 eyeVec: TEXCOORD3;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS_Distance(
	float4 Pos: POSITION,
	float3 Norm: NORMAL,
    float2 TexCdPos : TEXCOORD0,
    float2 TexCd : TEXCOORD1,
    float3 tang: TANGENT,
    float3 bino: BINORMAL)
{
    vs2ps Out = (vs2ps) 0;
	
	if(isPTxCd) Out.TexCd = mul(Pos, tTex);
	else Out.TexCd = mul(TexCd, tTex);
	float4 prePos = mul(Pos, TransformW);
	float3 preNorm = normalize(mul(Norm, TransformW));
	
	// Placement UV
    float4 PlaceCoords = float4(TexCdPos.x, prePos.z+0.5, 0, 1);
	// get position and direction data from textures
    float4 particleData = tex2Dlod(YResampSpl, PlaceCoords);
    float3 SplineDirection = tex2Dlod(DirSpl, PlaceCoords);
	// get pitch and yaw from direction vector
    float pitch = asin(SplineDirection.y)/TwoPi;
    float yaw = atan2(-SplineDirection.x, -SplineDirection.z)/ TwoPi;
	// Evaluate rotation matrix
    float4x4 rotMatrix = Vrotate(pitch, yaw,0);
	// POSITION
	float4 cprePos = 0;
	cprePos.yx = prePos * particleData.a;
    cprePos.z = 0;
    float4 splPos = mul(cprePos, rotMatrix) + float4(particleData.xyz,1);
	// NORMAL
    float3 cpreNorm = mul(preNorm, rotMatrix);
	
	float4 dispPos = splPos;
	float3 dispNorm = cpreNorm;
    float3x3 tangentMap = float3x3(tang, bino, dispNorm);
    tangentMap = mul(tangentMap, tW);
	float3 eyeVec = Out.wPos - matVI[3].xyz;	
	Out.eyeVec = mul(tangentMap, eyeVec);
	
    Out.Pos = mul(dispPos, tWVP);
    Out.wPos = mul(dispPos,tW);
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------
float4 PS_Distance(vs2ps In) : COLOR
{
	float2 itexcd = In.TexCd.xy;
	itexcd.x *= -1;
	float3 uvb = cone(itexcd, In.eyeVec, cone_map);
	float3 posWb = In.wPos.xyz/In.wPos.w;
	if(depth!=0) posWb += In.NormW * uvb.z * (-1*pow(depth,.5)) * posDepth;
	float shad = 1;
	
	float3 p1 = posWb;
	float3 p2 = p1 - LightPos;
    float dist = length(p2);
    return float4(dist.xxx, tex2D(Samp, In.TexCd).a);
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------
technique distance
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS_Distance();
        PixelShader = compile ps_3_0 PS_Distance();
    }
}