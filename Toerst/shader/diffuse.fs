uniform sampler2D tex;

uniform vec3 light;
uniform float gain;
uniform float diffuse;

void main()
{

 vec4 sum = vec4(0.0);
	 vec2 vTexCoord = gl_TexCoord[0].xy;

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
    
    gl_FragColor.x = -pow(2.0,-gl_FragColor.x*5.0)+1.0;
    gl_FragColor.y = -pow(2.0,-gl_FragColor.y*5.0)+1.0;
    gl_FragColor.z = -pow(2.0,-gl_FragColor.z*5.0)+1.0;
 //   gl_FragColor.xyz *= (texture.r > 0.0f) ? 1.0f : 0.0f;
//	   gl_FragColor.xyz *= (texture.r > 0.0) ? 1.0 : 0.0;
}