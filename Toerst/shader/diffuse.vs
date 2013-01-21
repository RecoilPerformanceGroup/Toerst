void main()
{
	gl_FrontColor = gl_Color;
	gl_Position = ftransform();
//	gl_TexCoord[0] = gl_MultiTexCoord0;
    gl_TexCoord[0] = (gl_Position ) * vec4(0.5,-0.5,1.0,1.0)- vec4(0.5,0.5,0,0);
//	gl_Position[0] += 0.1;
}
