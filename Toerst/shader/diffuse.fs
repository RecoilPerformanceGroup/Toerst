uniform sampler2D tex;

uniform vec3 light;
uniform float gain;
uniform float diffuse;

void main()
{

 vec4 sum = vec4(0.0);
	 vec2 vTexCoord = gl_TexCoord[0].xy;
	float blurSize = 1.0;
   // blur in y (vertical)
   // take nine samples, with the distance blurSize between them
 /*  sum += texture2D(tex, vec2(vTexCoord.x - 4.0*blurSize, vTexCoord.y)) * 0.05;
   sum += texture2D(tex, vec2(vTexCoord.x - 3.0*blurSize, vTexCoord.y)) * 0.09;
   sum += texture2D(tex, vec2(vTexCoord.x - 2.0*blurSize, vTexCoord.y)) * 0.12;
   sum += texture2D(tex, vec2(vTexCoord.x - blurSize, vTexCoord.y)) * 0.15;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y)) * 0.16;
   sum += texture2D(tex, vec2(vTexCoord.x + blurSize, vTexCoord.y)) * 0.15;
   sum += texture2D(tex, vec2(vTexCoord.x + 2.0*blurSize, vTexCoord.y)) * 0.12;
   sum += texture2D(tex, vec2(vTexCoord.x + 3.0*blurSize, vTexCoord.y)) * 0.09;
   sum += texture2D(tex, vec2(vTexCoord.x + 4.0*blurSize, vTexCoord.y)) * 0.05;*/
 /*
  sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y - 4.0*blurSize)) * 0.05;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y - 3.0*blurSize)) * 0.09;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y - 2.0*blurSize)) * 0.12;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y - blurSize)) * 0.15;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y)) * 0.16;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y + blurSize)) * 0.15;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y + 2.0*blurSize)) * 0.12;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y + 3.0*blurSize)) * 0.09;
   sum += texture2D(tex, vec2(vTexCoord.x, vTexCoord.y + 4.0*blurSize)) * 0.05;
 */

    vec4 texture = texture2D(tex, gl_TexCoord[0].xy);
//	vec4 texture = sum;
    
    vec3 normal = normalize(vec3(texture.g-0.5, texture.b-0.5, 0.2));
//	vec3 lightDir = normalize(vec3(0,1,0));
//    vec3 lightDir = normalize(vec3(gl_LightSource[0].position));
	vec3 lightDir = normalize(light);

	float NdotL = (1.0-diffuse) + diffuse* max(dot(normal, lightDir), 0.0);

//	vec4 diffuse = vec4(0,0,1.0,1.0);
    vec4 ambient = vec4(0.1,0.1,0.15,0.4);
	gl_FragColor = gl_Color * texture.a;// * NdotL + ambient;
    gl_FragColor.xyz *= NdotL * texture.r * gain;
 //   gl_FragColor.xyz *= (texture.r > 0.0f) ? 1.0f : 0.0f;
//	   gl_FragColor.xyz *= (texture.r > 0.0) ? 1.0 : 0.0;
}