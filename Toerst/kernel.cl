typedef struct{
	float2 vel;
	float2 f;
    float2 pos;
    float mass;
    //int2 texCoord;
    uint age;
    bool dead;
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
#define FORCE_CACHE_MULT 1000.f
#define COUNT_CREATE_BUFFER_MULT 100.0f


int getTexIndex(float2 pos, int textureWidth){
    
    int x = convert_int((float)pos.x*textureWidth);
    int y = convert_int((float)pos.y*textureWidth);
    return y*textureWidth+x;

}

__constant sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;



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


//######################################################
//  Particle Kernels
//######################################################
// Update the particles position 
//

kernel void update(global Particle* particles, global unsigned int * isDeadBuffer,  global unsigned  int * countInactiveCache, global unsigned int * countActiveBuffer, const float dt, const float damp, const float minSpeed, const float fadeInSpeed, const float fadeOutSpeed, const int textureWidth, global  int * forceCache, const float forceTextureForce, const float forceTextureForceMax)
{
    size_t i = get_global_id(0);
    size_t li = get_local_id(0);

    local bool isDead[1024];
    isDead[li] = isDeadBuffer[i/32] & (1<<(i%32));
    
    
    int byteNum = (li/32);
    local bool isModified[32];
    isModified[byteNum] = false;
 

    //--------- Age -----------

    /* if(!isDead[li]  ){
    //if(!p->dead){
        bool kill = particleAgeUpdate(p, fadeOutSpeed, fadeInSpeed);
        if(kill){
           
            p->dead = true;
           isDead[li] = true;
            isModified[byteNum] = true;
        }
    }*/
    
    
    //-------  Position --------
    if(!isDead[li]){
        __global Particle *p = &particles[i];

        p->age ++;
        
        p->vel *= damp;
        
        p->vel += p->f * p->mass;
        
        float speed = fast_length(p->vel);
        if(speed < minSpeed*0.1 * p->mass){
            p->vel  = (float2)(0,0);
        } else {
             p->f = (float2)(0,0);
        }
        
        if(fabs(p->vel.x) > 0 || fabs(p->vel.y) > 0){

            //Make sure its not inactive
            if(p->inactive){
                p->inactive = false;
             /*   int texIndex = getTexIndex(p->pos, textureWidth);
                atomic_dec(&countInactiveCache[texIndex]);*/
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
                /*if(p->inactive){
                    int texIndex = getTexIndex(p->pos, textureWidth);
                    atomic_dec(&countInactiveCache[texIndex]);
                    
                }*/
                p->dead = true;
                isDead[li] = true;
                isModified[byteNum] = true;
            }
        } else if(!p->inactive && p->alpha == 1 && p->age > 10){
            p->inactive = true;
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
    
    if(li%32 == 0 && isModified[byteNum]){
        unsigned int store = 0;
        for(int j=0;j<32;j++){
            store += isDead[li+j] << j;
        }
        isDeadBuffer[i/32] = store;
    }
}




kernel void addParticles(global Particle * particles, global unsigned int * isDeadBuffer, global unsigned int * countCreateBuffer, const int textureWidth, const int offset, const int numParticles, global unsigned int * countActiveBuffer){
    
    int global_id = get_global_id(0);
    int lid = get_local_id(0);
    int groupId = get_group_id(0);
    int groupSize = get_local_size(0);
    
    //Group size = 32
    //global size = TEX*TEX
    
    private bool isDead[32];
    
    
    int numberToAdd = countCreateBuffer[global_id]/COUNT_CREATE_BUFFER_MULT;
    
    if(numberToAdd > 0){
        
        unsigned int bufferId = (offset*32  + groupId * get_local_size(0) + lid) % (numParticles/32);
        private unsigned int isDeadBufferRead = isDeadBuffer[bufferId];

        
        if(isDeadBufferRead > 0){
            for(char bit=0;bit<32;bit++){
                
                isDead[bit] = isDeadBufferRead & (1<<bit);
                
                if(isDead[bit] && numberToAdd > 0){
                    int particleIndex = bufferId*32+bit;
                    
                    
                    
                    global Particle * p = &particles[particleIndex];
                    p->dead = false;
                    p->inactive = false;
                    p->vel = (float2)(0);
                    p->age = 0;
                    
                    p->pos.x =  (global_id % textureWidth) / 1024.0f;
                    p->pos.y = ((global_id - (global_id % textureWidth))/textureWidth) / 1024.0f;
                    
                    p->alpha = 1.0;
                    
                    int texIndex = getTexIndex(p->pos, textureWidth);
                    atomic_add(&countActiveBuffer[texIndex], 1000.0*p->alpha);
                    
                    isDead[bit] = false;
                    
                    
                    numberToAdd --;
                }
                
            }
            
            
            unsigned int store = 0;
            for(int j=0;j<32;j++){
                store += isDead[j] << j;
            }
            isDeadBuffer[bufferId] = store;
        }

        countCreateBuffer[global_id] = numberToAdd*COUNT_CREATE_BUFFER_MULT;
    }
}


//------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------


kernel void mouseForce(global int * forceField,  const float2 mousePos, const float mouseForce, float mouseRadius){
    int index = get_global_id(1)*get_global_size(0) + get_global_id(0);
    float x = convert_float(get_global_id(0))/get_global_size(0);
    float y = convert_float(get_global_id(1))/get_global_size(1);
    
    
    float2 diff = mousePos - (float2)(x,y);
    float dist = fast_length(diff);
    if(dist < mouseRadius){
        //float invDistSQ = 1.0f / dist;
       // float invDistSQ = (mouseRadius - dist)/mouseRadius;
        float x = (mouseRadius - dist)/mouseRadius;
        float invDistSQ = (x*x);
        
        diff = fast_normalize(diff);
        diff *= mouseForce * invDistSQ;
        
        forceField[index*2] +=  - diff.x*FORCE_CACHE_MULT;
        forceField[index*2+1] +=  - diff.y*FORCE_CACHE_MULT;
    }
}



//Force from forcefield texture
kernel void forceTextureForce(global Particle* particles,  global  int * forceCache, const float force, const float forceMax, const int textureWidth){
    
    int i = get_global_id(0);
    int lid = get_local_id(0);
    int localSize = 1024;
    int imageSize = textureWidth * textureWidth;
    
    global Particle *p = &particles[i];
    
    if(!p->dead){
        int texIndex = getTexIndex(p->pos, textureWidth);
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            float2 dir = (float2)(forceCache[texIndex*2]/FORCE_CACHE_MULT, forceCache[texIndex*2+1]/FORCE_CACHE_MULT);
            
            float l = fast_length(dir) ;
            if(l > 0.01){
                p->f += dir * force;
            }
        }
    }
}

//Force away from density
kernel void textureDensityForce(global Particle* particles, read_only image2d_t image, const float force){
    int id = get_global_id(0);
    //int width = get_image_width(image);
    float width = 1024.0f;
    
	global Particle *p = &particles[id];
    if(!p->dead){
        float2 texCoord = ((p->pos*(float2)(width,width)));
        float4 pixel = read_imagef(image, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, texCoord);
        
        float count = pixel.x;
        if(count > 0.0){
            float2 dir = (float2)(pixel.y-0.5, pixel.z-0.5);
          //  if(fast_length(dir) > 0.2){
                p->f += dir* (float2)(10.0 * force );//*(float2)(p->mass-0.3);
            //}
        }
    }
}


kernel void wind(global int * forceField, const float2 globalWind, const float3 pointWind ){
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

//------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------


kernel void mouseAdd(global unsigned int * countCreateBuffer,  const float2 addPos, const float mouseRadius, const float numAdd){
    if(numAdd == 0){
        return;
    }

    int index = get_global_id(1)*get_global_size(0) + get_global_id(0);
    float x = convert_float(get_global_id(0))/get_global_size(0);
    float y = convert_float(get_global_id(1))/get_global_size(1);
    
    float2 diff = addPos - (float2)(x,y);
    float dist = fast_length(diff);
    if(dist < mouseRadius){
        countCreateBuffer[index] += numAdd*(mouseRadius-dist)/mouseRadius;
    }
}


kernel void rectAdd(global unsigned int * passiveBuffer, const float4 rect, const float numAdd){
    int bufferId = get_global_id(1)*get_global_size(0) + get_global_id(0);
    
    float x = get_global_id(0)/1024.0f;//get_global_size(0);
    float y = get_global_id(1)/1024.0f;//get_global_size(1);
    
    if(x > rect[0] && x < rect[0]+rect[2] && y > rect[1] && y < rect[1]+rect[3])
    {
        passiveBuffer[bufferId] += numAdd;
    }
    
}

//------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------


kernel void sumParticleActivity(global Particle * particles, global unsigned int * countActiveBuffer, global unsigned int * countInactiveBuffer, const int textureWidth){
    global Particle * p = &particles[get_global_id(0)];

    int texIndex = getTexIndex(p->pos, textureWidth);
    if(!p->dead && texIndex > 0 && texIndex < textureWidth*textureWidth){
        if(p->inactive){
            atomic_inc(&countInactiveBuffer[texIndex]);
            
        } else {
            atomic_add(&countActiveBuffer[texIndex], 1000.0*p->alpha);
        }
    }   

}

kernel void sumParticles(global Particle * particles, global unsigned  int * countActiveBuffer, global unsigned int* isDeadBuffer, global int * forceField, const int textureWidth, global ParticleCounter * counter, const float forceFieldParticleInfluence){

    int id = get_global_id(0);
    
    global Particle *p = &particles[id];
    if(!p->dead && !p->inactive){
        int texIndex  = getTexIndex(p->pos, textureWidth);
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            if(forceFieldParticleInfluence > 0){
                atomic_add(&forceField[texIndex*2], p->vel.x*FORCE_CACHE_MULT*forceFieldParticleInfluence);
                atomic_add(&forceField[texIndex*2+1], p->vel.y*FORCE_CACHE_MULT*forceFieldParticleInfluence);
            }
        }
    }

    
    
}


kernel void sumCounter(global Particle * particles, global unsigned int* isDeadBuffer,global ParticleCounter * counter, local ParticleCounter * counterCache){
    int id = get_global_id(0);
    int lid = get_local_id(0);
    
    global Particle * p = &particles[id];
   /* counterCache[lid].deadParticles = 0;
    counterCache[lid].inactiveParticles = 0;
    counterCache[lid].activeParticles = 0;

    if(p->dead){
        counterCache[lid].deadParticles = 1;
    } else if(p->inactive){
        counterCache[lid].inactiveParticles = 1;
    } else {
        counterCache[lid].activeParticles = 1;
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
   int stride = 2;
    while(stride <= 1024/2){
        if(lid%stride == 0){
            counterCache[lid].deadParticles += counterCache[lid+stride/2].deadParticles;
            counterCache[lid].activeParticles += counterCache[lid+stride/2].activeParticles;
            counterCache[lid].inactiveParticles += counterCache[lid+stride/2].inactiveParticles;
        }
        stride *= 2;
        
        barrier(CLK_LOCAL_MEM_FENCE);
    }
    
    
    if(lid == 0){
        atomic_add(&counter[0].deadParticles, counterCache[0].deadParticles);
        atomic_add(&counter[0].inactiveParticles, counterCache[0].inactiveParticles);
        atomic_add(&counter[0].activeParticles, counterCache[0].activeParticles);
    }
    */
    
    
    
    //DEBUG
    if(p->dead){
     atomic_inc(&counter[0].deadParticles);
     } else if(p->inactive){
     atomic_inc(&counter[0].inactiveParticles);
     } else {
     atomic_inc(&counter[0].activeParticles);
     }
   /* if(isDeadBuffer[id/32] & (1<<(id%32))  ){
        atomic_inc(&counter[0].deadParticlesBit);
    }*/
    /* if(id%32 == 0){
     atomic_add(&counter[0].deadParticlesBit, popcount(as_int(isDeadBuffer[id/32])));
     
     }*/
    


}


//######################################################
//  Texture Kernels
//######################################################

kernel void updateForceTexture(write_only image2d_t image, global int * forceField){
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


//######################################################
//  Passive Kernels
//######################################################

kernel void passiveParticlesBufferUpdate(global unsigned int * passiveBuffer, global unsigned int * inactiveBuffer, global unsigned int * activeBuffer, global unsigned int * countCreateBuffer, global int * forceField, const float passiveMultiplier){

    int id = get_global_id(1) * get_global_size(0) +  get_global_id(0);
    int force = forceField[id*2] + forceField[id*2+1];
    
    //If no activity and there are inactive particles, make them all passive
    if(activeBuffer[id] == 0 && inactiveBuffer[id] > 0 && force == 0){
        passiveBuffer[id] += inactiveBuffer[id]/passiveMultiplier;
        inactiveBuffer[id] = 0;
    }
    
    
    
    bool createAllPassiveParticles = false;
    
    if(passiveBuffer[id] > 0 && inactiveBuffer[id] > 0){
        createAllPassiveParticles = true;
    }
    else if(passiveBuffer[id] > 0 && activeBuffer[id] > 0){
        createAllPassiveParticles = true;
    }
    else if(force != 0){
        createAllPassiveParticles = true;
    }

    
    if(createAllPassiveParticles){
        countCreateBuffer[id] += COUNT_CREATE_BUFFER_MULT*passiveBuffer[id]*passiveMultiplier;
        passiveBuffer[id] = 0;
    }
}


kernel void activateAllPassiveParticles(global unsigned int * passiveBuffer,  global unsigned int * countCreateBuffer, const float passiveMultiplier ){
    int id = get_global_id(1) * get_global_size(0) +  get_global_id(0);
    
    
    countCreateBuffer[id] += COUNT_CREATE_BUFFER_MULT*passiveBuffer[id]*passiveMultiplier;
    passiveBuffer[id] = 0;
    
}


kernel void passiveParticlesParticleUpdate(global Particle * particles, global unsigned int * passiveBuffer, global unsigned int * wakeUpBuffer, const int textureWidth, local int * wakeUpCache, global unsigned int *isDeadBuffer){
    
    int i = get_global_id(0);
    int lid = get_local_id(0);
    int local_size = get_local_size(0);
    
    local bool isDead[1024];
    local bool modifiedBuffer = false;

    isDead[lid] = isDeadBuffer[i/32] & (1<<(i%32));
    
    if(!isDead[lid]){
        if(particles[i].inactive){

            int texIndex = getTexIndex(particles[i].pos, textureWidth);
            if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
                if(passiveBuffer[texIndex] > 0){
                    particles[i].dead = true;
                    particles[i].inactive = false;
                    
                    isDead[lid] = true;
                    modifiedBuffer = true;
                }
            }
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
    if(modifiedBuffer){
        if(lid%32 == 0){
            unsigned int store = 0;
            for(int j=0;j<32;j++){
                store += isDead[lid+j] << j;
            }
            isDeadBuffer[i/32] = store;
        }
    }
}



kernel void updateTexture(read_only image2d_t readimage, write_only image2d_t image, local int * particleCountSum, global unsigned  int * countActiveBuffer, global unsigned  int * countInactiveBuffer, global unsigned  int * passiveBuffer,  const float passiveMultiplier){
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
    
    
    particleCountSum[tid] = countActiveBuffer[global_id] + countInactiveBuffer[global_id]*1000.0 +passiveBuffer[global_id]*1000.0*passiveMultiplier;
    
    
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
        diff[0] = count - (countActiveBuffer[global_id-1]+ countInactiveBuffer[global_id-1]*1000 + passiveBuffer[global_id-1]*1000.0*passiveMultiplier);
    }
    
    diff[1] = 0;
    if(lidx != get_local_size(0)-1){
        diff[1] = count - particleCountSum[tid+1];
    } else if(idx < width-1){
        diff[1] = count - (countActiveBuffer[global_id+1]+ countInactiveBuffer[global_id+1]*1000 + passiveBuffer[global_id+1]*1000.0*passiveMultiplier);
    }
    
    diff[2] = 0;
    if(lidy != 0){
        diff[2] = count - particleCountSum[tid-get_local_size(0)];
    } else if(global_id-width > 0){
        diff[2] = count - (countActiveBuffer[global_id-width]+ countInactiveBuffer[global_id-width]*1000 + passiveBuffer[global_id-width]*1000.0*passiveMultiplier);
    }
    
    diff[3] = 0;
    if(lidy != get_local_size(1)-1){
        diff[3] = count - particleCountSum[tid+get_local_size(0)];
    } else  if(idy < width-1){
        diff[3] = count - (countActiveBuffer[global_id+width]+ countInactiveBuffer[global_id+width]*1000 + passiveBuffer[global_id+width]*1000.0*passiveMultiplier);
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


kernel void resetCountCache(global unsigned  int * countInactiveBuffer,global unsigned  int * countActiveBuffer, global int * forceField){
    countActiveBuffer[get_global_id(0)] = 0;
    countInactiveBuffer[get_global_id(0)] = 0;
    forceField[get_global_id(0)*2] = 0;
    forceField[get_global_id(0)*2+1] = 0;
}



__kernel void gaussianBlurBuffer(global unsigned int * buffer, constant float * mask, private int maskSize, const float ammount, const float fadeAmmount){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int width = get_global_size(0);
    
    int global_id = idy*width + idx;
    
    // Collect neighbor values and multiply with Gaussian
    private float sum = 0.0f;
    
    for(int a = -maskSize; a < maskSize+1; a++) {
        for(int b = -maskSize; b < maskSize+1; b++) {
            
            if(idx+a > 0 && idy+b > 0 && idx+a < width && idx+b < width){
                int global_id_2 = (idy+b)*width + (idx+a);
                float bufferVal = buffer[global_id_2];
                sum += mask[ a + maskSize+(b+maskSize)*(maskSize*2+1)]* bufferVal;
            }
        }
    }
    
    //barrier(CLK_GLOBAL_MEM_FENCE);
    //forceCache[global_id*2]++;
    
    float r = convert_float(buffer[global_id]);
    
    buffer[global_id] =  convert_uint_sat_rtp((ammount*sum + r*(1.0f-ammount) )*fadeAmmount);
}



__kernel void gaussianBlurImage(
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