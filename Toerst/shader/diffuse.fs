uniform sampler2D tex;

uniform vec3 light;
uniform float gain;
uniform float diffuse;


uniform float time;
uniform vec2 resolution;

uniform float crazy;

uniform vec2 animalPos;
uniform float animalHeight;
uniform float animalRadius;
uniform float animalLight;

void main()
{
    
    
    vec2 halfres = resolution.xy/2.0;
    vec2 cPos = gl_FragCoord.xy;
    
    cPos.x -= 0.5*halfres.x*sin(time/2.0)+0.3*halfres.x*cos(time)+halfres.x;
    cPos.y -= 0.4*halfres.y*sin(time/5.0)+0.3*halfres.y*cos(time)+halfres.y;
    float cLength = length(cPos);
    
    vec2 uv = gl_TexCoord[0].xy+ crazy*(cPos/cLength)*sin(cLength/30.0-time*10.0)/25.0;
       
    
    //Animal
    float l = length(gl_TexCoord[0].xy - animalPos);
    l *= animalRadius;
    l = pow(3.0,-(l*l));

    uv.y += l*animalHeight*texture2D(tex,uv).x;
    
    
    vec3 col = texture2D(tex,uv).xyz;//*50.0/cLength;
    
    vec4 texture = vec4(col,1.0);
    
    texture *= (1.0+l*animalLight);
    
    
    
    
    
    vec3 normal = normalize(vec3(texture.g-0.5, texture.b-0.5, 0.2));

	vec3 lightDir = normalize(light);
	float NdotL = (1.0-diffuse) + diffuse* max(dot(normal, lightDir), 0.0);

    vec4 ambient = vec4(0.1,0.1,0.15,0.4);
	gl_FragColor = gl_Color * texture.a;// * NdotL + ambient;
    gl_FragColor.xyz *= NdotL * texture.r * gain;
    
    
    // Curve
    gl_FragColor.x = -pow(2.0,-gl_FragColor.x*5.0)+1.0;
    gl_FragColor.y = -pow(2.0,-gl_FragColor.y*5.0)+1.0;
    gl_FragColor.z = -pow(2.0,-gl_FragColor.z*5.0)+1.0;
    
    
    

//    gl_FragColor.x = texture2D(tex, gl_TexCoord[0].xy).x;
    
 //   gl_FragColor.xyz *= (texture.r > 0.0f) ? 1.0f : 0.0f;
//	   gl_FragColor.xyz *= (texture.r > 0.0) ? 1.0 : 0.0;
}