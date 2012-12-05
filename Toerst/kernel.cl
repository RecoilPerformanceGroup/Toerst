typedef struct{
	float2 vel;
	float2 f;
    float mass;
//    int texCoord;
} Particle;

#define COUNT_MULT 20.0f

kernel void update(global Particle* particles,  global float2* posBuffer, const float dt, const float damp, const float minSpeed)
{
    size_t i = get_global_id(0);
    
    __global Particle *p = &particles[i];
    
    p->vel *= damp;

    float force = fast_length(p->f);
    if(force > minSpeed * p->mass){
        p->vel += p->f * p->mass;
    }
    
    if(fabs(p->vel.x) > 0 || fabs(p->vel.y) > 0){
        p->f = (float2)(0,0);
        
        if(posBuffer[i].x >= 1)
            p->vel.x *= -1;
        
        if(posBuffer[i].y >= 1)
            p->vel.y *= -1;
        
        if(posBuffer[i].x <= 0)
            p->vel.x *= -1;
        
        if(posBuffer[i].y <= 0)
            p->vel.y *= -1;
        
        
        posBuffer[i] += p->vel * dt;
    }
}


kernel void mouseForce(global Particle* particles,  global float2* posBuffer, const float2 mousePos, const float mouseForce, float mouseRadius){
    int id = get_global_id(0);
	global Particle *p = &particles[id];
	
	float2 diff = mousePos - posBuffer[id];
    float dist = fast_length(diff);
    if(dist < mouseRadius){
        float invDistSQ = 1.0f / dist;
        diff *= mouseForce * invDistSQ;
        
        p->f +=  - diff;
    }
}

kernel void textureForce(global Particle* particles,  global float2 * posBuffer, read_only image2d_t image, const float force){
    int id = get_global_id(0);
    int width = get_image_width(image);

	global Particle *p = &particles[id];
    
    float2 texCoord = ((posBuffer[id]*(float2)(width,width)));
    float4 pixel = read_imagef(image, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, texCoord);
//    count -= 0.45;
    float count = pixel.x-1.0/COUNT_MULT;
    
    if(count > 0.0 && count <= 1.0){
//        float2 dir = texCoord - (floor(texCoord)+(float2)(0.5,0.5));

//            float2 dir = 0.1*(float2)(sin(p->mass*121.1),cos(p->mass*121.1));
        float2 dir;
         dir = (float2)(pixel.y-0.5, pixel.z-0.5);
        
        if(fast_length(dir) > 0.2){
        
//        p->f += normalize(dir)* (float2)(0.05);
     //   posBuffer[id] += normalize(dir)* (float2)(0.001*count);
          // p->vel += dir* (float2)(0.1 * force );
            p->f += dir* (float2)(0.1 * force )*(float2)(1.,p->mass);
        }
    }
}

kernel void updateTexture(write_only image2d_t image, global float2* posBuffer, const int numParticles, local int * particleCount){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int local_size = (int)get_local_size(0)*(int)get_local_size(1);
    int tid = get_local_id(1) * get_local_size(0) + get_local_id(0);
    
    int lidx =  get_local_id(0);
    int lidy =  get_local_id(1);
    
    int width = get_image_width(image);
    
    int groupx = get_group_id(0)*get_local_size(0);
    int groupy = get_group_id(1)*get_local_size(1);
    
  //  int count = 0;
    
    int2 pos = (int2)(idx, idy);
    particleCount[tid] = 0;
    
   /* for(int i=0;i<numParticles;i++){
        int x = convert_int((float)posBuffer[i].x*width);
        int y = convert_int((float)posBuffer[i].y*width);
        
        if(pos.x == x && pos.y == y){
            particleCount[tid]++;
        }
    
    }*/
    
    for(int i=tid;i<numParticles;i+=local_size){
        int x = convert_int((float)posBuffer[i].x*width) - groupx;
        int y = convert_int((float)posBuffer[i].y*width) - groupy;
        
        if(x >= 0 && x < get_local_size(0) && y >= 0 && y < get_local_size(1)){
            int index = y*get_local_size(0)+x;
            atomic_inc(&particleCount[index]);
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
    uchar count = particleCount[tid];
    float2 dir = (float2)(0.,0.);
    if(lidx != 0){
        int diff = count - particleCount[tid-1];
        if(diff > 0)
            dir = (float2)(-0.1*diff,0);
    }
    if(lidx != get_local_size(0)-1){
        int diff = count - particleCount[tid+1];
        if(diff > 0)
            dir += (float2)(0.1*diff,0);
    }
    if(lidy != 0){
        int diff = count - particleCount[tid-get_local_size(0)];
        if(diff > 0)
            dir += (float2)(0,-0.1*diff);
    }
    if(lidy != get_local_size(1)-1){
        int diff = count - particleCount[tid+get_local_size(0)];
        if(diff > 0)
            dir += (float2)(0,0.1*diff);
    }
    
    int2 coords = (int2)(get_global_id(0), get_global_id(1));
    
    float countColor = clamp((convert_float(particleCount[tid])/COUNT_MULT),0.0f,1.0f);
    float4 color = (float4)(countColor,dir.x+0.5,dir.y+0.5,1);
  //    float4 color = (float4)(clamp((convert_float(particleCount[tid])/10.0f),0.0f,1.0f),0,0,1);
   // float4 color = (float4)(1,0,0,1);
    write_imagef(image, coords, color);
}

kernel void fixTextureWorkgroupEdges(read_only image2d_t readImage, write_only image2d_t writeImage, const int num_groups_x){
    int tid = get_local_id(0);
    int size = get_local_size(0);
    int imageWidth = get_image_width(readImage);
    
    int2 offset = (int2)( (imageWidth/num_groups_x)* (get_group_id(0)%num_groups_x) ,
                         (imageWidth/num_groups_x) * (get_group_id(0) - (get_group_id(0)%num_groups_x)) / num_groups_x);
    
    int2 coord = (int2)(0,0);
    
    if(tid < size/4){
        coord.x = tid;
        coord.y = 0;
        
        coord += offset;
    }
    else if(tid < 2*(size/4)){
        coord.x = tid-(size/4);
        coord.y = (size/4)-1;
        
        coord += offset;
    }
    else if(tid < 3*(size/4)){
        coord.y = tid-2*(size/4);
        coord.x = 0;//(size/4)-1;
        
        coord += offset;
    } else {
        coord.y = tid-3*(size/4);
        coord.x = (size/4)-1;
        
        coord += offset;
        
        //float4 pixel = read_imagef(readImage, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, coord);
    }

    float4 pixel = read_imagef(readImage, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, coord);
    int count = pixel.x * COUNT_MULT;

    
    float4 n, e, s, w;
    n=e=s=w = (float4)(100,0,0,0);
    if(coord.y != 0){
        n = read_imagef(readImage, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, coord + (int2)(0,-1));
    }
    if(coord.y != imageWidth-1){
        s = read_imagef(readImage, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, coord + (int2)(0,1));
    }
    if(coord.x != 0){
        w = read_imagef(readImage, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, coord + (int2)(-1,0));
    }
    if(coord.x != imageWidth-1){
        e = read_imagef(readImage, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, coord + (int2)(1,0));
    }
    
    
    float2 dir = (float2)(0,0);
    
    int diff = count - w.x*COUNT_MULT;
    if(diff > 0)
        dir = (float2)(-0.1*diff,0);
    
    diff = count - e.x*COUNT_MULT;
    if(diff > 0)
        dir += (float2)(0.1*diff,0);

    diff = count - n.x*COUNT_MULT;
    if(diff > 0)
        dir += -(float2)(0,0.1*diff);

    diff = count - s.x*COUNT_MULT;
    if(diff > 0)
        dir += -(float2)(0,-0.1*diff);

    
    float4 color = pixel;
    color.y = dir.x+0.5;
    color.z = dir.y+0.5;
    
    write_imagef(writeImage, coord, color);

}

