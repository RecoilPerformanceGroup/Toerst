typedef struct{
	float2 vel;
	float2 f;
    float mass;
    //int2 texCoord;
    uint age;
    bool dead;
    float2 pos;
    float alpha;
    bool inactive;
   // float4 dummy;
    
} Particle;

typedef struct {
    float2 pos;
    float4 color;
} ParticleVBO;

typedef struct {
    int activeParticles;
    int inactiveParticles;
    int deadParticles;
    int deadParticlesBit;
} ParticleCounter;

#define COUNT_MULT 100.0f
//#define COUNT_MULT 5.0f
//#define COUNT_MULT 5.0f
#define FORCE_CACHE_MULT 1000.f


void killParticle(global Particle * particle){//, global int * isDeadBuffer){
    
    particle->dead = true;
    
  /*  isDeadBuffer[i/32]
    int isDead =
    bool isDead = isDead & 1<<(i%32);
*/
}

int getTexIndex(float2 pos, int textureWidth){
    
    int x = convert_int((float)pos.x*textureWidth);
    int y = convert_int((float)pos.y*textureWidth);
    return y*textureWidth+x;

}


//######################################################
//  Particle Updates
//######################################################

bool particleAgeUpdate(global Particle * p, const float fadeOutSpeed, const float fadeInSpeed){
    p->age ++;
    
    p->alpha =  smoothstep(0,1,p->age * fadeInSpeed) - smoothstep(0,1,p->age * fadeOutSpeed);
    
    if(p->alpha <= 0){
        return true;
    }
    
    return false;

    
//    
//    
//    if(fadeOutSpeed > 0 && p->age > 100 /*&&*/ /*fast_length(p->vel) < 0.001 &&*/ && p->alpha > 0){
//        p->alpha -= fadeOutSpeed*(p->mass-0.4);
//        
//        if(p->alpha < 0){
//            return true;
//        }
//
//    } else if(p->alpha < 0.1*p->mass){
//        p->alpha += fadeInSpeed*p->mass;
//    }
//    
//    return false;
    
}
/*
void forceTextureForceUpdate(global Particle* p, global int * forceCache, const float force, const float forceMax, const int textureWidth){
    
    int x = convert_int((float)p->pos.x*textureWidth);
    int y = convert_int((float)p->pos.y*textureWidth);
    int texIndex = y*textureWidth+x;
    
    if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
        float2 dir = (float2)(forceCache[texIndex*2]/FORCE_CACHE_MULT, forceCache[texIndex*2+1]/FORCE_CACHE_MULT);
        
        float l = fast_length(dir) ;
        if(l > forceMax){
            dir = fast_normalize(dir);
            dir *= forceMax;
        }
        if(l > 0){
            p->f += dir * force;
        }
    }
}*/


//######################################################
//  Particle Kernels
//######################################################
// Update the particles position 
//

kernel void update(global Particle* particles, global unsigned int * isDeadBuffer,  global unsigned  int * countInactiveCache, const float dt, const float damp, const float minSpeed, const float fadeInSpeed, const float fadeOutSpeed, const int textureWidth, global unsigned  int * forceCache, const float forceTextureForce, const float forceTextureForceMax)
{
    size_t i = get_global_id(0);
    size_t li = get_local_id(0);
    
  //  local bool isDead[1024];
   
    local bool isDead[1024];
    /*local int isDeadInt[32];
    if(li%32 == 0){
        isDeadInt[li/32] = isDeadBuffer[i/32];
    }
    */
    
    //barrier(CLK_LOCAL_MEM_FENCE);
    
    
   // uint isDeadInt = isDeadBuffer[i/32];
    //isDead[li] = isDead[li] & 1<<(i%32);
//    isDead[li] = isDeadInt[li/32] & (1<<(i%32));
    isDead[li] = isDeadBuffer[i/32] & (1<<(i%32));
 
    __global Particle *p = &particles[i];
    
    if(!isDead[li]  ){
    //if(!p->dead){
        //------- Age --------
        bool kill = particleAgeUpdate(p, fadeOutSpeed, fadeInSpeed);
        if(kill){
            if(p->inactive){
                int texIndex = getTexIndex(p->pos, textureWidth);
                atomic_dec(&countInactiveCache[texIndex]);
                
            }
            killParticle(p);
           isDead[li] = true;
        }
    }
    
    //-------  Position --------
    if(!isDead[li]){
//    if(!p->dead){

        p->vel *= damp;
        
        p->vel += p->f * p->mass;
        
        float speed = fast_length(p->vel);
        if(speed < minSpeed*0.1 * p->mass){
            p->vel  = (float2)(0,0);
        }
        
        if(fabs(p->vel.x) > 0 || fabs(p->vel.y) > 0){

            //Make sure its not inactive
            if(p->inactive){
                p->inactive = false;
                int texIndex = getTexIndex(p->pos, textureWidth);
                atomic_dec(&countInactiveCache[texIndex]);
            }
            
            p->f = (float2)(0,0);
            
            float2 pos = p->pos + p->vel * dt;
            
            p->pos = pos;
            
            
            //Boundary check
            bool kill = false;
            if(p->pos.x >= 1){
                kill = true;
            }
            
            if(p->pos.y >= 1){
                kill = true;
            }
            
            if(p->pos.x <= 0){
                kill = true;
            }
            
            if(p->pos.y <= 0){
                kill = true;
            }
            
            if(kill){
                if(p->inactive){
                    int texIndex = getTexIndex(p->pos, textureWidth);
                    atomic_dec(&countInactiveCache[texIndex]);
                    
                }
                killParticle(p);
                isDead[li] = true;
                
            }

            
        } else if(!p->inactive && p->alpha == 1){
            p->inactive = true;
            
            int texIndex = getTexIndex(p->pos, textureWidth);
            atomic_inc(&countInactiveCache[texIndex]);
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);

    
    if(li%32 == 0){
        unsigned int store = 0;
        for(int j=0;j<32;j++){
            store += isDead[li+j] << j;
        }
        isDeadBuffer[i/32] = store;
    }
}





kernel void mouseForce(global unsigned int * forceField,  const float2 mousePos, const float mouseForce, float mouseRadius){
    
    int index = get_global_id(1)*get_global_size(0) + get_global_id(0);
    float x = convert_float(get_global_id(0))/get_global_size(0);
    float y = convert_float(get_global_id(1))/get_global_size(1);
    
    
    
    float2 diff = mousePos - (float2)(x,y);
    float dist = fast_length(diff);
    if(dist < mouseRadius){
        float invDistSQ = 1.0f / dist;
        
        diff = fast_normalize(diff);
        diff *= mouseForce * invDistSQ;
        
        forceField[index*2] +=  - diff.x*FORCE_CACHE_MULT;
        forceField[index*2+1] +=  - diff.y*FORCE_CACHE_MULT;
    }
}

kernel void mouseAdd(global unsigned int * countCreateBuffer,  const float2 addPos, const float mouseRadius, const int numAdd){
    if(numAdd == 0){
        return;
    }
    
    
    int index = get_global_id(1)*get_global_size(0) + get_global_id(0);
    float x = convert_float(get_global_id(0))/get_global_size(0);
    float y = convert_float(get_global_id(1))/get_global_size(1);

    
    float2 diff = addPos - (float2)(x,y);
    float dist = fast_length(diff);
    if(dist < mouseRadius){
        atomic_inc(&countCreateBuffer[index]);
    }

}




kernel void addParticles(global Particle * particles, global unsigned int * isDeadBuffer, global unsigned int * countCreateBuffer, const int textureWidth, const int offset, const int numParticles){
    
    int global_id = get_global_id(0);
    int lid = get_local_id(0);
    int groupId = get_group_id(0);
    
    local bool isDead[32];
    local bool createNew[32];
    local int isDeadBufferRead;
    
    // for(int it=0;it<numParticles/32;it++){
    int bufferId = (groupId);// % (numParticles/32);
    
    isDeadBufferRead= isDeadBuffer[bufferId];
    //isDead[lid] = isDeadBufferRead & (1<<lid);
    isDead[lid] = (isDeadBuffer[bufferId]) & (1<<lid);
    //createNew[lid] = countCreateBuffer[global_id];
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
    
    for(int i=0;i<1;i++){
        int r = (i+lid)%32;
        
        if(isDead[r] && countCreateBuffer[global_id] > 0){
            isDead[r] = false;

            countCreateBuffer[global_id]--;
            
            
            global Particle * p = &particles[bufferId*32+r];
            p->dead = false;
            p->inactive = false;
            p->vel = (float2)(0);
            p->age = 0;
            
            p->pos.x =  (global_id % textureWidth) / 1024.0f;
            p->pos.y = ((global_id - (global_id % textureWidth))/textureWidth) / 1024.0f;
            
            p->alpha = 1.0;
            
            
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
    if(lid == 0){
        unsigned int store = 0;
        for(int j=0;j<32;j++){
            store += isDead[j] << j;
        }
        isDeadBuffer[bufferId] = store;
    }
    
    //  }
    
    /*__global Particle * p = &particles[i];
     
     
     if(p->dead){
     
     for(int j=0;j<1000;j+=100){
            int bufferId = (j+get_global_id(0)+offset) % bufferSize;
     
            if(countCreateBuffer[bufferId] > 0){
                int read = atomic_dec(&countCreateBuffer[bufferId]);
                if(read > 0){
                    p->dead = false;
                    p->inactive = false;
                    p->vel = (float2)(0);
                    p->age = 0;
     
                    p->pos.x = (bufferId % textureWidth) / 1024.0f;
                    p->pos.y = ((bufferId - (bufferId % textureWidth))/textureWidth) / 1024.0f;
                    p->alpha = 1.0;
                    break;
                }
            }
        }
    }
   */
}

/*
kernel void addParticles(global Particle * particles, global unsigned int * isDeadBuffer, global int * countCreateBuffer, const int textureWidth, const int offset, const int numParticles){
 
    int global_id = get_global_id(0);
 
    int numInts = numParticles/32;
 
    int bufferSize = textureWidth*textureWidth;
 
    private int read;
 
 
    if(countCreateBuffer[global_id] > 0){
        //if(1){
        for(int i=0;i<numInts;i++){
            int j=(offset+i+global_id)%numInts;
            //int j= i;
            
            if(isDeadBuffer[j] > 0){
                
                for(int bindex=0;bindex<32;bindex++){
                    read = isDeadBuffer[j] ;
                    if(read & (1<<bindex)){
                        
                        int read = atomic_dec(&countCreateBuffer[global_id]);
                        if(read > 0){
                            
                            //            char bindex = 32-clz(isDeadBuffer[j]);
                            int index = bindex + j*32;
                            
                            global Particle * p = &particles[index];
                            p->dead = false;
                            p->inactive = false;
                            p->vel = (float2)(0);
                            p->age = 0;
                            
                            p->pos.x =   / 1024.0f;
                            p->pos.y = ((global_id - (global_id % textureWidth))/textureWidth) / 1024.0f;
                            
                            p->alpha = 1.0;
                            
                            isDeadBuffer[j] = isDeadBuffer[j] ^ (1 << bindex);
                            
                            return;
                        }
                    }
                }
                
                
            }
        }
    }
    
    /*__global Particle * p = &particles[i];
     
     
     if(p->dead){
     
     for(int j=0;j<1000;j+=100){
     int bufferId = (j+get_global_id(0)+offset) % bufferSize;
     
     if(countCreateBuffer[bufferId] > 0){
     int read = atomic_dec(&countCreateBuffer[bufferId]);
     if(read > 0){
     p->dead = false;
     p->inactive = false;
     p->vel = (float2)(0);
     p->age = 0;
     
     p->pos.x = (bufferId % textureWidth) / 1024.0f;
     p->pos.y = ((bufferId - (bufferId % textureWidth))/textureWidth) / 1024.0f;
     p->alpha = 1.0;
     break;
     }
     }
     }
     }
     }
*/
kernel void rectAdd(global Particle * particles, const float4 rect, const float numAdd, const int numParticles, const float randomSeed,const float randomSeed2){
    if(numAdd == 0){
        return;
    }
    
    int id = get_global_id(0);
    int size = get_global_size(0);
    
    int fraction = numParticles / size;
    
    int added = 0;
    for(int i=id*fraction ; i<id*fraction+fraction ; i++){
        global Particle * p = &particles[i];
        if(p->dead){
            float fi = i;
            //float2 pi = sin(fi*1.1423)*(float2)(sin(fi)*0.5,cos(fi)*0.5)*rect.zw + rect.xy;
            
            float x = (convert_int(0.12312f*i*randomSeed) % 1024)/1024.0f;
            float y = (convert_int(0.0123479*i*randomSeed2) % 1024)/1024.0f;
            //float x = (i % 100*(randomSeed*100.0f))/(10000.0f*randomSeed);
            //float y = (i % 143*(randomSeed*100.0f))/(14300.0f*randomSeed);
            float2 pi = (float2)(x,y);
            
            pi *= rect.zw;
            pi += rect.xy;
            
            p->dead = false;
            p->inactive = false;
            p->vel = (float2)(0);
            p->age = 0;
            p->pos = pi;
            p->alpha = 0.0;
            //  posBuffer[i].color = (float4)(1,1,1,0);
            added ++;
        }
        
        if(numAdd == added)
            break;
    }

}

kernel void textureForce(global Particle* particles, read_only image2d_t image, const float force){
    int id = get_global_id(0);
    int width = get_image_width(image);
    
	global Particle *p = &particles[id];
    if(!p->dead){
        
        float2 texCoord = ((p->pos*(float2)(width,width)));
        float4 pixel = read_imagef(image, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, texCoord);
        
        float count = pixel.x;//-1.0/COUNT_MULT;
        if(count > 0.0){// && count <= 1.0){
            float2 dir = (float2)(pixel.y-0.5, pixel.z-0.5);
            
//            if(fast_length(dir) > 0.2){
                p->f += dir* (float2)(10.0 * force )*(float2)(p->mass-0.3);
//            }
        }
    }
}

kernel void forceTextureForce(global Particle* particles,  global unsigned  int * forceCache, const float force, const float forceMax, const int textureWidth/*, local int2 * forceCacheLocal*/){
    
    int i = get_global_id(0);
    int lid = get_local_id(0);
    int localSize = 1024;//get_local_size(0);
    int imageSize = textureWidth * textureWidth;
    
    global Particle *p = &particles[i];
    
    if(!p->dead ){
        
        int texIndex = getTexIndex(p->pos, textureWidth);

        
        /*int start = 0;
       
        int jump = 5;
        for(int j=lid ; j<imageSize ; j+=localSize*jump){
            for(int q=0;q<jump;q++){
                forceCacheLocal[lid*jump+q] = (int2)(forceCache[(j+q)*2] ,forceCache[(j+q)*2+1]);
            }
            
            barrier(CLK_LOCAL_MEM_FENCE);
            
         
         
            if(texIndex >= start && texIndex < start+localSize*jump){
               // float2 dir = (float2)(forceCacheLocal[texIndex-start].x/FORCE_CACHE_MULT, forceCacheLocal[texIndex-start].y/FORCE_CACHE_MULT);
                float2 dir = (float2)(forceCache[texIndex*2]/FORCE_CACHE_MULT, forceCache[texIndex*2+1]/FORCE_CACHE_MULT);
                //
                //float2 dir = (float2)(0,0);
                float l = fast_length(dir) ;
                //           if(l > forceMax){
                //                dir = fast_normalize(dir);
                //                dir *= forceMax;
                //            }
                if(l > 0){
                    p->f += dir * force;
                }
            }
            
            start += localSize*jump;
        }
        */
        
        
        
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            float2 dir = (float2)(forceCache[texIndex*2]/FORCE_CACHE_MULT, forceCache[texIndex*2+1]/FORCE_CACHE_MULT);
            
         //
        //    float2 dir = (float2)(0,0);
              float l = fast_length(dir) ;
//           if(l > forceMax){
//                dir = fast_normalize(dir);
//                dir *= forceMax;
//            }
            if(l > 0.01){
                p->f += dir * force;
            }
        }
    }
}

kernel void sumParticles(global Particle * particles, global unsigned  int * countActiveBuffer, global unsigned int* isDeadBuffer, global unsigned  int * forceField, const int textureWidth, global ParticleCounter * counter, const float forceFieldParticleInfluence){
    int id = get_global_id(0);
    
    global Particle *p = &particles[get_global_id(0)];
    if(!p->dead && !p->inactive){
        int i = get_global_id(0);
        int x = convert_int((float)p->pos.x*textureWidth);
        int y = convert_int((float)p->pos.y*textureWidth);
        int texIndex = y*textureWidth+x;
        
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
           atomic_add(&countActiveBuffer[texIndex], 1000.0*p->alpha);
            
            if(forceFieldParticleInfluence > 0){
                atomic_add(&forceField[texIndex*2], p->vel.x*FORCE_CACHE_MULT*forceFieldParticleInfluence);
                atomic_add(&forceField[texIndex*2+1], p->vel.y*FORCE_CACHE_MULT*forceFieldParticleInfluence);
            }
        }
    }
    
    if(p->dead){
        atomic_inc(&counter[0].deadParticles);
    } else if(p->inactive){
        atomic_inc(&counter[0].inactiveParticles);
    } else {
        atomic_inc(&counter[0].activeParticles);
    }
    
    
   /* unsigned int intRead;
    int count;
    
    if(id%32==0){
        intRead = isDeadBuffer[id/32];
        if(intRead > 0){
            for(int i=0;i<32;i++){
                if(intRead & (1<<i)){
                    count++;
                }
            }
            
            atomic_add(&counter[0].deadParticlesBit,count);
        }
    }*/
    
    /*
    
    barrier(CLK_LOCAL_MEM_FENCE);

    count += (intRead & (1<<(id%32)));
    
    barrier(CLK_LOCAL_MEM_FENCE);

    if(id%32==0){
        atomic_add(&counter[0].deadParticlesBit,count);

    }*/
/*
    if(intRead & (1<<(id%32))  ){
        atomic_inc(&counter[0].deadParticlesBit);
    }
    */
    
}


/*
 kernel void sumParticles2(global Particle * particles, global ParticleVBO* posBuffer, global int * countInactiveBuffer, global int * forceCache, const int numParticles, local int * localArea ){
    
    int textureWidth = get_global_size(0);
    int localSize = get_local_size(0);
    int lid = get_local_id(1) * get_local_size(0) + get_local_id(0);
    
    int gx = get_group_id(0)*localSize;
    int gy = get_group_id(1)*localSize;
    
    for(int i=lid;i<numParticles;i+= localSize*localSize){

        int x = convert_int((float)posBuffer[i].pos.x*textureWidth);
        int y = convert_int((float)posBuffer[i].pos.y*textureWidth);
        int texIndex = y*textureWidth+x;
        
        if(texIndex >= 0
           && texIndex < textureWidth*textureWidth
           && x >= gx
           && x < gx+localSize
           && y >= gy
           && y < gy+localSize){
            int lTexIndex = (y-gy)*localSize + (x-gx);
            
            localArea[lTexIndex] ++;
//            atomic_inc(&countInactiveBuffer[texIndex]);
//            
//            atomic_add(&forceCache[texIndex*2], p->vel.x*FORCE_CACHE_MULT);
//            atomic_add(&forceCache[texIndex*2+1], p->vel.y*FORCE_CACHE_MULT);
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
}
*/
__constant sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;

__kernel void gaussian_blur(
                            __read_only image2d_t image,
                            __constant float * mask,
                            write_only image2d_t blurredImage,
                            __private int maskSize
                            ) {
    
    const int2 pos = {get_global_id(0), get_global_id(1)};
    float4 pixel = read_imagef(image, sampler, pos);
    
    // Collect neighbor values and multiply with gaussian
    float2 sum = 0.0f;
    // Calculate the mask size based on sigma (larger sigma, larger mask)
    for(int a = -maskSize; a < maskSize+1; a++) {
        for(int b = -maskSize; b < maskSize+1; b++) {
            sum += mask[a+maskSize+(b+maskSize)*(maskSize*2+1)]
            *read_imagef(image, sampler, pos + (int2)(a,b)).yz;
        }
    }
    
    write_imagef(blurredImage, pos, (float4)(pixel.x,sum.x,sum.y,1) );
//    blurredImage[pos.x+pos.y*get_global_size(0)] = sum;
}

__kernel void gaussianBlurSum(
                              global int * forceCache,
                              global int * forceCacheBlur,
                              const int textureWidth,
                              __constant float * mask,
                              __private int maskSize
                              ) {
    
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int global_id = idy*textureWidth + idx;
    
    // Collect neighbor values and multiply with Gaussian
    float2 sum = (float2)(0.0f,0.0f);
    for(int a = -maskSize; a < maskSize+1; a++) {
        for(int b = -maskSize; b < maskSize+1; b++) {
            
            if(idx+a > 0 && idy+b > 0 && idx+a < textureWidth && idx+b < textureWidth){
                int global_id_2 = (idy+b)*textureWidth + (idx+a);
                float2 force = (float2)(forceCache[global_id_2*2], forceCache[global_id_2*2+1]);
//                float2 force =  (float2)(1000,0);
                sum += mask[ a + maskSize+(b+maskSize)*(maskSize*2+1)]* force; //read_imagef(image, sampler, pos + (int2)(a,b)).x;
                
//                sum +=
            }
        }
    }
    
    //barrier(CLK_GLOBAL_MEM_FENCE);
    //forceCache[global_id*2]++;
    forceCacheBlur[global_id*2] = convert_int_sat(sum.x);
    forceCacheBlur[global_id*2+1] = convert_int(sum.y);;
    //blurredImage[pos.x+pos.y*get_global_size(0)] = sum;
}

//######################################################
//  Texture Kernels
//######################################################




kernel void resetCountCache(global unsigned  int * countInactiveBuffer, global unsigned  int * forceField){
    countInactiveBuffer[get_global_id(0)] = 0;
    forceField[get_global_id(0)*2] = 0;
    forceField[get_global_id(0)*2+1] = 0;
}

kernel void updateForceTexture(write_only image2d_t image, global unsigned  int * forceField){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int global_id = idy*get_image_width(image) + idx;
    
    int2 coords = (int2)(idx, idy);
    float2 force = (float2)(forceField[global_id*2]/FORCE_CACHE_MULT, forceField[global_id*2+1]/FORCE_CACHE_MULT);
    
    
    float4 color = (float4)(0,0,0,1);
    color += (float4)(1,0,0,0)*max(0.f , force.x*0.5f);
    color -= (float4)(0,0,1,0)*min(0.f , force.x*0.5f);
    color += (float4)(1,1,0,0)*max(0.f , force.y*0.5f);
    color -= (float4)(0,1,0,0)*min(0.f , force.y*0.5f);
    
    write_imagef(image, coords, color);
    
}

kernel void passiveParticlesBufferUpdate(global int * passiveBuffer, global int * inactiveBuffer, global int * activeBuffer, global int * wakeUpBuffer, global int * forceField){
    int id = get_global_id(1) * get_global_size(0) +  get_global_id(0);
    
    int force = forceField[id*2] + forceField[id*2+1];
    
    if(activeBuffer[id] == 0 && inactiveBuffer[id] > 0 && force == 0){
        passiveBuffer[id] = inactiveBuffer[id];
        inactiveBuffer[id] = 0;
    }
    
    if(force != 0){
        atomic_add(&wakeUpBuffer[id], passiveBuffer[id]);
        passiveBuffer[id] = 0;
    }
}

kernel void passiveParticlesParticleUpdate(global Particle * particles, global int * passiveBuffer, global int * wakeUpBuffer, const int textureWidth, local int * wakeUpCache){
    int i = get_global_id(0);
    int lid = get_local_id(0);
    int local_size = get_local_size(0);
    
    if(!particles[i].dead){
        int texIndex = getTexIndex(particles[i].pos, textureWidth);
        
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            if(passiveBuffer[texIndex] > 0){
                particles[i].dead = true;
                particles[i].inactive = false;
            }
        }
    }
    /*
    int globalCacheId = (lid + get_group_id(0)*get_local_size(0));
    
    if( globalCacheId < textureWidth*textureWidth){
        wakeUpCache[lid] = wakeUpBuffer[globalCacheId];
        int orig = (wakeUpCache[lid]);
        
        barrier(CLK_LOCAL_MEM_FENCE);
        
        global Particle * p = &particles[i];
        if(p->dead){
            for(int j=0;j<local_size;j++){
                if(wakeUpCache[j] > 0){
                    int wakeUpRead = atomic_dec(&wakeUpCache[j]);
                    if  (wakeUpRead > 0){
                        
                        int w = textureWidth;
                        
                        float x = (j + get_group_id(0)*get_local_size(0)) % w;
                        float y = ((j + get_group_id(0)*get_local_size(0)) - x)/w;
                        
                        
                        float2 point = (float2)(x/textureWidth, y/textureWidth);
                        
                        
                        p->dead = false;
                        p->inactive = false;
                        p->pos = point;
                        p->alpha = 1;
                        p->age = 0;
                        p->vel = (float2)(0);
                        
                        int texIndex = getTexIndex(point, textureWidth);
                        atomic_add(&countActiveBuffer[texIndex], 1000.0);

                        
                        break;
                    }
                }
                
            }
        }
        
        barrier(CLK_LOCAL_MEM_FENCE);
        
        //        atomic_sub(&wakeUpBuffer[globalCacheId], orig - wakeUpCache[lid]);
        wakeUpBuffer[globalCacheId] = 0;
    }
    */
    /*
    int globalCacheId = (lid + get_group_id(0)*get_local_size(0));
    
    if( globalCacheId < textureWidth*textureWidth){
        int origWakeUpBuffer = (wakeUpBuffer[lid]);
        
        if(origWakeUpBuffer > )

    }
    */
    
    //    for(int i=0;i<numParticles;i++){
    //
    //        if(id == texIndex){
//            particles[i].dead = true;
//            particles[i].inactive = false;
//        }
//        
//    }
   
   

}

kernel void updateTexture(read_only image2d_t readimage, write_only image2d_t image, local int * particleCountSum, global unsigned  int * countActiveBuffer, global unsigned  int * countInactiveBuffer, global unsigned  int * countPassiveBuffer){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int local_size = (int)get_local_size(0)*(int)get_local_size(1);
    int tid = get_local_id(1) * get_local_size(0) + get_local_id(0);
    
    
    int lidx =  get_local_id(0);
    int lidy =  get_local_id(1);
    
    int width = get_image_width(image);
    
    int groupx = get_group_id(0)*get_local_size(0);
    int groupy = get_group_id(1)*get_local_size(1);
    
    int global_id = idy*width + idx;
    
    
    //------
    
    
    particleCountSum[tid] = countActiveBuffer[global_id] + countInactiveBuffer[global_id]*1000.0 + countPassiveBuffer[global_id]*1000.0;
    
    
    //--------
    barrier(CLK_LOCAL_MEM_FENCE);
    //--------
    
    
    
    int count = particleCountSum[tid];
    int diff[4];
    
    float2 dir = (float2)(0.,0.);
    int minDiff = 0;
    
    diff[0] = 0;
    if(lidx != 0){
        diff[0] = count - particleCountSum[tid-1];
    } else if(idx > 0) {
        diff[0] = count - (countActiveBuffer[global_id-1]+ countInactiveBuffer[global_id-1]*1000 + countPassiveBuffer[global_id-1]*1000.0);
    }
    
    diff[1] = 0;
    if(lidx != get_local_size(0)-1){
        diff[1] = count - particleCountSum[tid+1];
    } else if(idx < width-1){
        diff[1] = count - (countActiveBuffer[global_id+1]+ countInactiveBuffer[global_id+1]*1000 + countPassiveBuffer[global_id+1]*1000.0);
    }
    
    diff[2] = 0;
    if(lidy != 0){
        diff[2] = count - particleCountSum[tid-get_local_size(0)];
    } else if(global_id-width > 0){
        diff[2] = count - (countActiveBuffer[global_id-width]+ countInactiveBuffer[global_id-width]*1000 + countPassiveBuffer[global_id-width]*1000.0);
    }
    
    diff[3] = 0;
    if(lidy != get_local_size(1)-1){
        diff[3] = count - particleCountSum[tid+get_local_size(0)];
    } else  if(idy < width-1){
        diff[3] = count - (countActiveBuffer[global_id+width]+ countInactiveBuffer[global_id+width]*1000 + countPassiveBuffer[global_id+width]*1000.0);
    }

    
    
 /*   int num = 0;
    int _diff = diff[0];
    for(int i=1;i<4;i++){
        if(diff[i] > diff[num]){
            _diff = diff[i];
            num = i;
        }
    }
    
    
    if(_diff > minDiff){
        switch(num){
            case 0:
                dir = (float2)(-0.1*_diff,0);
                break;
            case 1:
                dir += (float2)(0.1*_diff,0);
                break;
            case 2:
                dir += (float2)(0,-0.1*_diff);
                break;
            case 3:
                dir += (float2)(0,0.1*_diff);
                break;
            default:
                break;
        }
    }
    */
    
    dir = (float2)(-diff[0],0);
    dir += (float2)(diff[1],0);
    dir += (float2)(0,-diff[2]);
    dir += (float2)(0,diff[3]);

    
    /* if(idx == 0 || idx == 1 || idx == width-1)
     dir = (float2)(0,0);
     */
    
    int2 coords = (int2)(get_global_id(0), get_global_id(1));
    
    dir *= 0.005;
    
    dir /= 1000.0;
    
    float countColor = clamp(((convert_float(particleCountSum[tid])/1000.0f)/COUNT_MULT),0.0f,1.0f);

    float4 color = (float4)(countColor,
                            clamp(dir.x+0.5f , 0.0f, 1.0f),
                            clamp(dir.y+0.5f , 0.0f, 1.0f),
                            1);

    
    /*    if(dir.x > 0.5 || dir.x < -0.5 ){
        color = (float4)(0,0,1,1);
    }
    if( dir.y > 0.5 || dir.y < -0.5 ){
        color = (float4)(0,1,0,1);
    }*/
  /* if((particleCountSum[tid]/COUNT_MULT) > 1.0){
        color = (float4)(1,1,1,1);
    }
    */
    float4 read = read_imagef(readimage, sampler, coords);

    float4 wcolor = color * 0.5f + read * 0.5f;
    
    //    float4 color = (float4)(clamp((convert_float(particleCountSum[tid])/10.0f),0.0f,1.0f),0,0,1);
    // float4 color = (float4)(1,0,0,1);
    write_imagef(image, coords, wcolor);
    
    //barrier(CLK_GLOBAL_MEM_FENCE);
    
    //--------
    //   countActiveBuffer[global_id] = 0;
    //--------
    
}





kernel void wind(global unsigned  int * forceField, const float2 globalWind, const float3 pointWind ){
    int index = get_global_id(1)*get_global_size(0) + get_global_id(0);
    float x = convert_float(get_global_id(0))/get_global_size(0);
    float y = convert_float(get_global_id(1))/get_global_size(1);

    
    forceField[index*2] += globalWind.x;
    forceField[index*2+1] += globalWind.y;
    
    //---
    float pointDist = distance((float2)(x,y), (float2)(pointWind.x, pointWind.y));
    float2 pointDir = normalize((float2)(x,y) - (float2)(pointWind.x, pointWind.y)) * 1.0/pointDist;
    forceField[index*2] += pointDir.x*pointWind.z;
    forceField[index*2+1] += pointDir.y*pointWind.z;
   
    
}
