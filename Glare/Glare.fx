float2 R;
float Brightness <float uimin=0.0;float uimax=1.0;> = 0.1;
float Shape = 0.1;
float PreBlurWidth=0;
texture tex0,tex1;
sampler s0=sampler_state{Texture=(tex0);MipFilter=LINEAR;MinFilter=LINEAR;MagFilter=LINEAR;AddressU=BORDER;AddressV=BORDER;};
sampler s1=sampler_state{Texture=(tex1);MipFilter=LINEAR;MinFilter=LINEAR;MagFilter=LINEAR;};
float4 pPRE(float2 vp:vpos):color{float2 x=(vp+.5)/R;
    float lod=1+log2(max(R.x,R.y));
    float4 c=tex2D(s0,x);
	for(float i=0;i<7;i++){
		c+=tex2D(s0,x+sin((i/7.+float2(.25,0))*acos(-1)*2)*PreBlurWidth/R);
	}
	c/=8.;
	c.rgb=pow(length(c.rgb)/sqrt(2),4)*normalize(c.rgb)*sqrt(2);
	
	//c.rgb=smoothstep(1,1.3,lerp(c.rgb,dot(c.rgb,.333),.85))*17;
	//c.rgb=max(0,lerp(c.rgb,dot(c.rgb,.333),.85)-1);
    return c;
}
float2 r2d(float2 x,float a){a*=acos(-1)*2;return float2(cos(a)*x.x+sin(a)*x.y,cos(a)*x.y-sin(a)*x.x);}

float4 pGLOW(float2 vp:vpos):color{float2 x=(vp+.5)/R;
    float lod=1+log2(max(R.x,R.y));
    float4 c=0;
    for(float i=0;i<lod;i++){
    	c+=pow(float4(tex2Dlod(s0,float4(x+r2d(vp%4-2,i*.25+.125)/R*.5*pow(2,i),0,i+1)).rgb,1)*pow(2,i*Shape-lod+1),.8);
    }
	c.rgb/=c.a;
	//c=pow(c,1);
	//c=c+pow(tex2D(s1,x),1+c*2);
	c.a=length(tex2D(s0,x).rgb);
    return c;
}
float4 pMIX(float2 vp:vpos):color{float2 x=(vp+.5)/R;
    float lod=1+log2(max(R.x,R.y));
    float4 s=tex2D(s1,x);
	float4 g=tex2Dlod(s0,float4(x,0,3));
	//float4 c=tex2D(s0,x);
	for(float i=0;i<5;i++){
		g+=tex2Dlod(s0,float4(x+sin((i/5.+float2(.25,0))*acos(-1)*2)*2/R,0,3));
	}
	g/=6;
	float4 c=s;
	//c=pow(s,1+length(g.rgb)*.007)+g;

	g*=Brightness*.5*pow(tex2Dlod(s0,float4(x,0,33)).a,1./4.)/12.;
	
	//g*=Brightness*111122.5/pow(tex2Dlod(s0,float4(x,0,33)).a,1./4.)/12.;
	//s*=sqrt(tex2Dlod(s0,float4(x,0,33)).a);
	c=s/(1+g*2)+g;

	//c=s+g*Brightness*318;
	
	//c=g+pow(s,1+g);
	//c.rgb=normalize(s.rgb)*pow(length(s.rgb)/sqrt(3),1+g*2)*sqrt(3)+g;
	//c/=1+3*tex2Dlod(s0,float4(x,0,33));
	c.a=s.a;
	c.a=1;
    return c;
}
void vs2d(inout float4 vp:POSITION0,inout float2 uv:TEXCOORD0){vp.xy*=2;uv+=.5/R;}
technique Pre{pass pp0{vertexshader=compile vs_3_0 vs2d();pixelshader=compile ps_3_0 pPRE();}}
technique Glow{pass pp0{vertexshader=compile vs_3_0 vs2d();pixelshader=compile ps_3_0 pGLOW();}}
technique Mix{pass pp0{vertexshader=compile vs_3_0 vs2d();pixelshader=compile ps_3_0 pMIX();}}
