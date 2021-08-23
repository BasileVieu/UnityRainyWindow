Shader "Unlit/RainyWindow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Size ("Size", float) = 1
        _T ("Time", float) = 1
        _Distortion ("Distortion", range(-5, 5)) = 1
        _Blur ("Blur", range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Transparent" }
        LOD 100
        
        GrabPass { "_GrabTexture" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 grabUv : TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _GrabTexture;
            float4 _MainTex_ST;
            float _Size;
            float _T;
            float _Distortion;
            float _Blur;

            v2f vert (appdata _v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(_v.vertex);
                o.uv = TRANSFORM_TEX(_v.uv, _MainTex);
                o.grabUv = UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex))
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float N21(float2 _p)
            {
                _p = frac(_p * float2(123.34, 345.45));
                _p += dot(_p, _p + 34.345);

                return frac(_p.x * _p.y);
            }

            float3 Layer(float2 _uv, float _t)
            {
                float2 aspect = float2(2, 1);

                float2 uv = _uv * _Size * aspect;
                uv.y += _t * 0.25;

                float2 gv = frac(uv) - 0.5;

                float2 id = floor(uv);

                float n = N21(id);

                _t += n * 6.2831;

                float w = _uv.y * 10;
                
                float x = (n - 0.5) * 0.8;
                x += (0.4 - abs(x)) * sin(3 * w) * pow(sin(w), 6) * 0.45;
                
                float y = -sin(_t + sin(_t + sin(_t) * 0.5)) * 0.45;
                y -= (gv.x - x) * (gv.x - x);

                float2 dropPos = (gv - float2(x, y)) / aspect;

                float drop = smoothstep(0.05, 0.03, length(dropPos));

                float2 trailPos = (gv - float2(x, _t * 0.25)) / aspect;
                trailPos.y = (frac(trailPos.y * 8) - 0.5) / 8;

                float trail = smoothstep(0.03, 0.01, length(trailPos));
                
                float fogTrail = smoothstep(-0.05, 0.05, dropPos.y);
                fogTrail *= smoothstep(0.5, y, gv.y);

                trail *= fogTrail;

                fogTrail *= smoothstep(0.05, 0.04, abs(dropPos.x));

                float2 offs = drop * dropPos + trail * trailPos;

                return float3(offs, fogTrail);
            }

            fixed4 frag (v2f _i) : SV_Target
            {
                float4 col = 0;

                float t = fmod(_Time.y * _T, 7200);

                float3 drops = Layer(_i.uv, t);
                drops += Layer(_i.uv * 1.23 + 7.54, t);
                drops += Layer(_i.uv * 1.35 + 1.54, t);
                drops += Layer(_i.uv * 1.57 - 7.54, t);

                float fade = 1 - saturate(fwidth(_i.uv) * 60);

                float blur = _Blur * 7 * (1 - drops.z * fade);

                //col = tex2Dlod(_MainTex, float4(_i.uv + drops.xy * _Distortion, 0, blur));

                float2 projUv = _i.grabUv.xy / _i.grabUv.w;
                projUv += drops.xy * _Distortion * fade;

                blur *= 0.01;

                const float numSamples = 4;

                float a = N21(_i.uv) * 6.2831;

                for (float i = 0; i < numSamples; i++)
                {
                    float2 offs = float2(sin(a), cos(a)) * blur;

                    float d = frac(sin((i + 1) * 546) * 5424);
                    d = sqrt(d);
                    
                    offs *= d;
                    
                    col += tex2D(_GrabTexture, projUv + offs);

                    a++;
                }

                col /= numSamples;

                return col;
            }
            ENDCG
        }
    }
}