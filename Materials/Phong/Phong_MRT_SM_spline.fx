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

#define NUM_ITERATIONS 16
#define NUM_ITERATIONS_RELIEF1 11
#define NUM_ITERATIONS_RELIEF2 5

//texture
texture TexBump <string uiname="Bump Map";>;
sampler2D cone_map = sampler_state
{
	Texture = <TexBump>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
texture TexNorm <string uiname="Normal Map";>;
sampler2D normal_map = sampler_state
{
	Texture = <TexNorm>;
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
texture pTexYResampSpl <string uiname="previous Y Resampled Texture (spline)";>;
sampler pYResampSpl = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (pTexYResampSpl);          //apply a texture to the sampler
    MipFilter = linear;         //sampler states
    MinFilter = linear;
    MagFilter = linear;
    AddressU = clamp;//mirror;
    AddressV = clamp;//mirror;
};
texture pTexDirSpl <string uiname="previous Direction Texture";>;
sampler pDirSpl = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (pTexDirSpl);          //apply a texture to the sampler
    MipFilter = linear;         //sampler states
    MinFilter = linear;
    MagFilter = linear;
    AddressU = clamp;//mirror;
    AddressV = clamp;//mirror;
};
float4x4 TransformW <string uiname="Mesh Transform";>;
float4x4 pTransformW <string uiname="Previous Mesh Transform";>;
float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;
float4x4 ptTex: TEXTUREMATRIX <string uiname="previous Texture Transform";>;
float4x4 ptWVP <string uiname="previus WorldViewProj Transform";>;
float velGain <string uiname="Velocity Gain";> = 1;
float3 mbcorr = float3(0.0039,-0.0075,-0.1);
bool isPTxCd <string uiname="Position as Texture Coordinates";> = 0;
float alphatest = 0.5;

#include "phong.fxh"
float3 mainlPos <string uiname="Main Light Position";> = 0;

#include "..\shadows.fxh"
float shadowsAmount = 0;

#define minTwoPi -6.283185307179586476925286766559
#define TwoPi 6.283185307179586476925286766559

float depth = 0.1;
float posDepth = 0.3;
float normamount = 1;
bool DEPTH_BIAS = false;
bool BORDER_CLAMP = false;
float3 size_source;

float reflectStrength
<
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.01;
    string UIName =  "Reflection";
> = 0;

float refractStrength
<
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.01;
    string UIName =  "Refraction";
> = 0;

float rrBump
<
    string UIName =  "Bumpiness";
> = 0;
half3 etas
<
    string UIName = "Refraction indices";
> = { 0.80, 0.82, 0.84 };

texture cubeMap : Environment
<
	string ResourceName = "default_reflection.dds";
	string ResourceType = "Cube";
>;

texture fresnelTex : Environment
<
	string ResourceType = "2D";
	string function = "generateFresnelTex";
	
	float2 Dimensions = { 256.0f, 1.0f};
>;

samplerCUBE environmentMapSampler = sampler_state
{
	Texture = <cubeMap>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};

sampler2D fresnelSampler = sampler_state
{
	Texture = <fresnelTex>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = None;
};
float gi <string uiname="Global Illumination Intensity";> = 1;
// -----------------------------------------------------------------------------
// MISC:
// -----------------------------------------------------------------------------
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
		
		//float stepDist = height * cone_ratio / (rayVec.z*cone_ratio + dist);
		float stepDist = height * cone_ratio / (cone_ratio + dist);
		rayPos += rayVec * stepDist;
		
		///1
		// float4 tex = tex2D(cone_map, rayPos.xy);
		// float height = max(0, tex.w - rayPos.z);
		// float stepDist = height * 0.2;
		// rayPos += rayVec * stepDist;
		
		//float stepDist = height * cone_ratio / (cone_ratio + 0.1);
		///2
		//rayPos += rayVec * height * cone_ratio / (rayVec.z*cone_ratio + dist);
		
	}
	
	return rayPos.xyz;
}

float3 refract2( float3 I, float3 N, float eta, out bool fail )
{
	float IdotN = dot(I, N);
	float k = 1 - eta*eta*(1 - IdotN*IdotN);
//	return k < 0 ? (0,0,0) : eta*I - (eta*IdotN + sqrt(k))*N;
	fail = k < 0;
	return eta*I - (eta*IdotN + sqrt(k))*N;
}

// approximate Fresnel function
float fresnel(float NdotV, float bias, float power)
{
   return bias + (1.0-bias)*pow(1.0 - max(NdotV, 0), power);
}

// function to generate a texture encoding the Fresnel function
float4 generateFresnelTex(float NdotV : POSITION) : COLOR
{
	return fresnel(NdotV, 0.2, 4.0);
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

// -----------------------------------------------------------------------------
// STRUCT:
// -----------------------------------------------------------------------------
struct appdata
{
    float4 PosO: POSITION;
    float3 NormO: NORMAL;
    float2 TexCdPos: TEXCOORD0;
    float2 TexCdO: TEXCOORD1;
    float3 tang: TANGENT;
    float3 bino: BINORMAL;
};

struct vs2ps2
{
    float4 PosWVPp: POSITION ;
    float4 PosWVP: TEXCOORD0 ;
    float4 PosW: TEXCOORD1 ;
    float3 PosWV : TEXCOORD2 ;
    float3 NormWV: NORMAL ;
    float3 NormW: TEXCOORD3 ;
    float3 ViewDirWV: TEXCOORD4 ;
	float2 TexCd: TEXCOORD5 ;
	float3 eyeVec: TEXCOORD6 ;
    float4 vel : TEXCOORD7 ;
};

// -----------------------------------------------------------------------------
// VERTEXSHADERS:
// -----------------------------------------------------------------------------

// PLACE and DEFORM technique
vs2ps2 VS(appdata In)
{
    //inititalize all fields of output struct with 0
    vs2ps2 Out = (vs2ps2)0;
	
	float4 prePos = mul(In.PosO, TransformW);
	float4 ppprePos = mul(In.PosO, pTransformW);
	float3 preNorm = normalize(mul(In.NormO, TransformW));
	
	// Placement UV
    float4 PlaceCoords = float4(In.TexCdPos.x, prePos.z+0.5, 0, 1);
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
	
	float4 pparticleData = tex2Dlod(pYResampSpl, PlaceCoords);
    float3 pSplineDirection = tex2Dlod(pDirSpl, PlaceCoords);
	// get pitch and yaw from direction vector
    float ppitch = asin(pSplineDirection.y)/TwoPi;
    float pyaw = atan2(-pSplineDirection.x, -pSplineDirection.z)/ TwoPi;
	// Evaluate rotation matrix
    float4x4 protMatrix = Vrotate(ppitch, pyaw,0);
	// POSITION
	float4 pprePos = 0;
	pprePos.yx = ppprePos * pparticleData.a;
    pprePos.z = 0;
    float4 psplPos = mul(pprePos, protMatrix) + float4(pparticleData.xyz,1);
	
    Out.PosW = mul(splPos, tW);
    Out.PosWV = mul(splPos, tWV);
    Out.PosWVPp = mul(splPos, tWVP);
    Out.PosWVP = mul(splPos, tWVP);
	if(isPTxCd) Out.TexCd = mul(prePos, tTex);
	else Out.TexCd = mul(In.TexCdO, tTex);
	
	float3 npos = Out.PosWVP.xyz;
	float3 pnpos = mul(psplPos, ptWVP).xyz;
	Out.vel.rgb = (npos - pnpos) * velGain + mbcorr;
	Out.vel.a = 1;

    //normal in view space
    Out.NormWV = normalize(mul(cpreNorm, tWV));
    
    float3x3 tangentMap = float3x3(In.tang, In.bino, In.NormO);
    tangentMap = mul(tangentMap, tW);
	float3 eyeVec = Out.PosW - matVI[3].xyz;	
	Out.eyeVec = mul(tangentMap, eyeVec);

	//Out.ViewDirV = -normalize(mul(Out.PosW, tWV));
    Out.ViewDirWV = -normalize(mul(splPos, tWV));
	
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
	float3 normb = In.NormWV;
	float3 normWb = In.NormW;
	float2 itexcd = In.TexCd.xy;
	itexcd.x *= -1;
	float3 uvb = cone(itexcd, In.eyeVec, cone_map);
	if(depth!=0) normb += ((2 * (tex2D(normal_map,itexcd))) - 1.0)*-depth;
	float3 posWb = In.PosW;
	if(depth!=0) posWb += In.NormW * uvb.z * (-1*pow(depth,.5)) * posDepth;
	float3 posb = In.PosWV;
	if(depth!=0) posb += In.NormWV * uvb.z * (-1*pow(depth,.5)) * posDepth;
	float3 ViewDirWV = -normalize(posb);
	float shad = 1;
	if(shadowsAmount!=0) shad = lerp(1, softShadows(posWb, In.PosWVP, mainlPos).shadow, shadowsAmount);
	
	float alphat = 1;
	float alphatt = tex2D(diffSamp, uvb.xy).a;
	alphat = alphatt;
	if(alphatest!=0) alphat = lerp(alphatt, (alphatt>=alphatest), min(alphatest*10,1));

	c.color.rgb = PhongPoint(
		In.PosW,
		normb,
		ViewDirWV,
		shad,
		uvb.xy
	);

	//POSITION
    c.space.xyz = In.PosWV;
	if(depth!=0) c.space.xyz += posb;
    c.space.w = alphat;
	
	//ReflectRefract
	if((reflectStrength!=0) || (refractStrength!=0))
	{
	float3 rrnorm = ((2 * (tex2D(normal_map,itexcd))) - 1.0)*-rrBump;
	half3 rrN = normalize(mul(In.NormWV+rrnorm,matVI));
	float3 rrV = normalize(matVI[3].xyz - (In.PosW.xyz+rrN*uvb.z*-1*rrBump*posDepth));
    half3 rrR = reflect(-rrV, rrN);
    half4 reflColor = texCUBE(environmentMapSampler, rrR);
	half fresnel = tex2D(fresnelSampler, dot(rrN, rrV));
	const half4 colors[3] =
        {
    	{ 1, 0, 0, 1 },
    	{ 0, 1, 0, 1 },
    	{ 0, 0, 1, 1 },
	};
	half4 transColor = 0;
  	bool fail = false;
    for(int i=0; i<3; i++) {
    	half3 rrT = refract2(-rrV, rrN, etas[i], fail);
    	transColor += texCUBE(environmentMapSampler, rrT)* colors[i];
	}
	c.color += reflColor*reflectStrength*2*fresnel;
	c.color += transColor*refractStrength*(1-fresnel);
	}
	
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
    	//ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 VS();
        PixelShader  = compile ps_3_0 PS1();
    }
}

