typedef struct{
	float2 vel;
	float2 f;
    float mass;
    //int2 texCoord;
    uint age;
    bool dead;
    
} Particle;

typedef struct {
    float2 pos;
    float4 color;
} ParticleVBO;

#define COUNT_MULT 20.0f
#define FORCE_CACHE_MULT 1000.f


void killParticle(global Particle * particle, global ParticleVBO * pos){
    particle->dead = true;
    pos->pos.x = -1;
    pos->pos.y = -1;
}


//######################################################
//  Particle Kernels
//######################################################


kernel void update(global Particle* particles,  global ParticleVBO* posBuffer, const float dt, const float damp, const float minSpeed, const float fadeOutSpeed)
{
    size_t i = get_global_id(0);
    
    __global Particle *p = &particles[i];
    
    if(!p->dead){
        p->age ++;
        
        
//        if(p->age > 100){
        if(fadeOutSpeed > 0 && p->age > 100 && fast_length(p->vel) < 0.001 && posBuffer[i].color.a > 0){
            posBuffer[i].color.a -= fadeOutSpeed*p->mass;
            
            if(posBuffer[i].color.a < 0){
                killParticle(p,&posBuffer[i]);
            }
            
        } else if(posBuffer[i].color.a < 0.2*p->mass){
            posBuffer[i].color.a += 0.01;
        }
        
        if(!p->dead){
            p->vel *= damp;
            
            float force = fast_length(p->f);
            if(force > minSpeed * p->mass){
                p->vel += p->f * p->mass;
            }
            
            if(fabs(p->vel.x) > 0 || fabs(p->vel.y) > 0){
                p->f = (float2)(0,0);
                
                posBuffer[i].pos += p->vel * dt;
                
                if(posBuffer[i].pos.x >= 1){
                    //            p->vel.x *= -1;
                    //                p->dead = true;
                    //              posBuffer[i].x -= 1;
                    killParticle(p, posBuffer+i);
                    //            posBuffer[i] = (float2)(0.5);
                }
                
                if(posBuffer[i].pos.y >= 1){
                    //    p->vel.y *= -1;
                    killParticle(p, posBuffer+i);
                }
                //            posBuffer[i] = (float2)(0.5);
                
                if(posBuffer[i].pos.x <= 0){
                    //            p->vel.x *= -1;
                    killParticle(p, posBuffer+i);
                }
                //            posBuffer[i] = (float2)(0.5);
                
                if(posBuffer[i].pos.y <= 0){
                    //            p->vel.y *= -1;
                    killParticle(p, posBuffer+i);
                }
                //          posBuffer[i] = (float2)(0.5);
                
            }
        }
    }
}


kernel void mouseForce(global Particle* particles,  global ParticleVBO* posBuffer, const float2 mousePos, const float mouseForce, float mouseRadius){
    int id = get_global_id(0);
	global Particle *p = &particles[id];
    if(!p->dead){
        
        float2 diff = mousePos - posBuffer[id].pos;
        float dist = fast_length(diff);
        if(dist < mouseRadius){
            float invDistSQ = 1.0f / dist;
            diff *= mouseForce * invDistSQ;
            
            p->f +=  - diff;
        }
        
    }
}

kernel void mouseAdd(global Particle * particles, global ParticleVBO* posBuffer, const float2 addPos, const float mouseRadius, const int numAdd, const numParticles ){
    
    int id = get_global_id(0);
    int size = get_global_size(0);
    
    int fraction = numParticles / size;
    
    int added = 0;
    for(int i=id*fraction ; i<id*fraction+fraction ; i++){
        float fi = i;
        global Particle * p = &particles[i];
        if(p->dead){
            float2 offset = (float2)(sin(fi),cos(fi*1.3)) * mouseRadius*0.1 * sin(i*43.73214);
            
            p->dead = false;
            p->vel = (float2)(0);
            p->age = 0;
            posBuffer[i].pos = addPos + offset;
            posBuffer[i].color = (float4)(1,1,1,0);
            added ++;
        }
        
        if(numAdd == added)
            break;
    }
    
}

kernel void textureForce(global Particle* particles,  global ParticleVBO* posBuffer, read_only image2d_t image, const float force){
    int id = get_global_id(0);
    int width = get_image_width(image);
    
	global Particle *p = &particles[id];
    if(!p->dead){
        
        float2 texCoord = ((posBuffer[id].pos*(float2)(width,width)));
        float4 pixel = read_imagef(image, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, texCoord);
        
        float count = pixel.x-1.0/COUNT_MULT;
        if(count > 0.0 && count <= 1.0){
            float2 dir = (float2)(pixel.y-0.5, pixel.z-0.5);
            
            if(fast_length(dir) > 0.2){
                p->f += dir* (float2)(0.1 * force )*(float2)(p->mass-0.5);
            }
        }
    }
}

kernel void forceTextureForce(global Particle* particles,  global ParticleVBO* posBuffer, global int * forceCache, const float force, const float forceMax, const int textureWidth){
    int i = get_global_id(0);
    global Particle *p = &particles[i];
    
    if(!p->dead){
        
        
        int x = convert_int((float)posBuffer[i].pos.x*textureWidth);
        int y = convert_int((float)posBuffer[i].pos.y*textureWidth);
        int texIndex = y*textureWidth+x;
        
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            
            
            float2 dir = (float2)(forceCache[texIndex*2]/FORCE_CACHE_MULT, forceCache[texIndex*2+1]/FORCE_CACHE_MULT);
            
            if(fast_length(dir) > forceMax){
                dir = fast_normalize(dir);
                dir *= forceMax;
            }
            p->f += dir * force;
        }
    }
}

kernel void sumParticles(global Particle * particles, global ParticleVBO* posBuffer, global int * countCache, global int * forceCache, const int textureWidth){
    global Particle *p = &particles[get_global_id(0)];
    if(!p->dead){
        
        int i = get_global_id(0);
        
        int x = convert_int((float)posBuffer[i].pos.x*textureWidth);
        int y = convert_int((float)posBuffer[i].pos.y*textureWidth);
        int texIndex = y*textureWidth+x;
        
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            atomic_inc(&countCache[texIndex]);
            atomic_add(&forceCache[texIndex*2], particles[i].vel.x*FORCE_CACHE_MULT);
            atomic_add(&forceCache[texIndex*2+1], particles[i].vel.y*FORCE_CACHE_MULT);
        }
    }
}


//######################################################
//  Texture Kernels
//######################################################


kernel void resetCountCache(global int * countCache, global int * forceCache){
    countCache[get_global_id(0)] = 0;
    forceCache[get_global_id(0)*2] = 0;
    forceCache[get_global_id(0)*2+1] = 0;
}

kernel void updateForceTexture(write_only image2d_t image, global int * forceCache){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int global_id = idy*get_image_width(image) + idx;
    
    int2 coords = (int2)(idx, idy);
    float2 force = (float2)(forceCache[global_id*2]/FORCE_CACHE_MULT, forceCache[global_id*2+1]/FORCE_CACHE_MULT);
    
    
    float4 color = (float4)(0,0,0,1);
    color += (float4)(1,0,0,0)*max(0.f , force.x*0.1f);
    color -= (float4)(0,0,1,0)*min(0.f , force.x*0.1f);
    color += (float4)(1,1,0,0)*max(0.f , force.y*0.1f);
    color -= (float4)(0,1,0,0)*min(0.f , force.y*0.1f);
    
    write_imagef(image, coords, color);
    
}

kernel void updateTexture(write_only image2d_t image, global ParticleVBO* posBuffer, const int numParticles, local int * particleCount, global int * countCache){
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
    
    
    particleCount[tid] = countCache[global_id];
    
    
    //--------
    barrier(CLK_LOCAL_MEM_FENCE);
    //--------
    
    
    
    uchar count = particleCount[tid];
    int diff;
    
    diff = 0;
    float2 dir = (float2)(0.,0.);
    if(lidx != 0){
        diff = count - particleCount[tid-1];
    } else if(idx > 0) {
        diff = count - convert_uchar_sat(countCache[global_id-1]);
    }
    if(diff > 0){
        dir = (float2)(-0.1*diff,0);
    }
    
    diff = 0;
    if(lidx != get_local_size(0)-1){
        diff = count - particleCount[tid+1];
    } else if(idx < width-1){
        diff = count - convert_uchar_sat(countCache[global_id+1]);
    }
    if(diff > 0){
        dir += (float2)(0.1*diff,0);
    }
    
    diff = 0;
    if(lidy != 0){
        diff = count - particleCount[tid-get_local_size(0)];
    } else if(global_id-width > 0){
        diff = count - convert_uchar_sat(countCache[global_id-width]);
    }
    if(diff > 0){
        dir += (float2)(0,-0.1*diff);
    }
    
    diff = 0;
    if(lidy != get_local_size(1)-1){
        diff = count - particleCount[tid+get_local_size(0)];
    } else  if(idy < width-1){
        diff = count - convert_uchar_sat(countCache[global_id+width]);
    }
    if(diff > 0){
        dir += (float2)(0,0.1*diff);
    }
    
    /* if(idx == 0 || idx == 1 || idx == width-1)
     dir = (float2)(0,0);
     */
    
    int2 coords = (int2)(get_global_id(0), get_global_id(1));
    
    float countColor = clamp((convert_float(particleCount[tid])/COUNT_MULT),0.0f,1.0f);
    float4 color = (float4)(countColor,dir.x+0.5,dir.y+0.5,1);
    //    float4 color = (float4)(clamp((convert_float(particleCount[tid])/10.0f),0.0f,1.0f),0,0,1);
    // float4 color = (float4)(1,0,0,1);
    write_imagef(image, coords, color);
    
    //barrier(CLK_GLOBAL_MEM_FENCE);
    
    //--------
    //   countCache[global_id] = 0;
    //--------
    
}

