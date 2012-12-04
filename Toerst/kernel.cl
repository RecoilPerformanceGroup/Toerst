typedef struct{
	float2 vel;
	float2 f;
    float mass;
} Particle;


kernel void update(global Particle* particles,  global float2* posBuffer, const float dt, const float damp, const float minSpeed)
{
    size_t i = get_global_id(0);

    __global Particle *p = &particles[i];
    
    float force = fast_length(p->f);
    if(force < minSpeed * p->mass) p->f *= 0.0;

    
    p->vel *= damp;
    p->vel += p->f * p->mass;

    p->f[0] = 0;
    p->f[1] = 0;
    
    p->vel.x *= 1.0 - 2.0*isgreater(posBuffer[i][0], 1);
    p->vel.y *= 1.0 - 2.0*isgreater(posBuffer[i][1], 1);

    p->vel.x *= 1.0 - 2.0*isless(posBuffer[i][0], 0);
    p->vel.y *= 1.0 - 2.0*isless(posBuffer[i][1], 0);


    posBuffer[i] += p->vel * dt;
}


kernel void mouseForce(global Particle* particles,  global float2* posBuffer, const float2 mousePos, const float mouseForce){
    int id = get_global_id(0);
	__global Particle *p = &particles[id];
	
	float2 diff = mousePos - posBuffer[id];
	float invDistSQ = 1.0f / dot(diff, diff);
	diff *= mouseForce * invDistSQ;
    
	p->f +=  - diff;
}

kernel void updateTexture(write_only image2d_t image, global float2* posBuffer, const int numParticles){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    
    int width = get_image_width(image);
    
    private int count = 0;
    
    int2 pos = (int2)(idx, idy);
    
    for(int i=0;i<numParticles;i++){
     /*   float dist = fast_distance(pos, (float2)(width,width)*posBuffer[i]);
        
        if(dist < 1){
            count++;
        }*/
        
        //int2 posI = (int2)((float2)(width,width)*posBuffer[i]);
        
        int x = convert_int((float)posBuffer[i].x*width);
        int y = convert_int((float)posBuffer[i].y*width);
        
        if(pos.x == x && pos.y == y){
            count++;
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
    int2 coords = (int2)(get_global_id(0), get_global_id(1));
    float4 color = (float4)(clamp(count,0,2)/2.0,0,0,1);
   // float4 color = (float4)(1,0,0,1);
    write_imagef(image, coords, color);

}

kernel void clearTexture(write_only image2d_t image){
    int2 coords = (int2)(get_global_id(0), get_global_id(1));
    
    //float4 color	= read_imagef(srcImage, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, coords);
    
    float4 color;
    color[0] = 0.0;
    color[1] = 0.0;
    color[2] = 0.0;
    color[3] = 1.0;
    write_imagef(image, coords, color);
}
