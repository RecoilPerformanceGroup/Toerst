typedef struct{
	float2 vel;
	float mass;
	float dummy;		// need this to make sure the float2 vel is aligned to a 16 byte boundary
} Particle;


kernel void update(global Particle* particles,  global float2* posBuffer, const float dt)
{
    size_t i = get_global_id(0);

    __global Particle *p = &particles[i];
    
    p->vel *= 0.99;
    

    posBuffer[i] += p->vel * dt;
}
/*
kernel void test(global Particle * particle){
    
}*/