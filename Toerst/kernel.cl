typedef struct{
	float2 vel;
	float2 f;
    float mass;
} Particle;


kernel void update(global Particle* particles,  global float2* posBuffer, const float dt, const float damp, const float minSpeed)
{
    size_t i = get_global_id(0);

    __global Particle *p = &particles[i];
    
    float force = length(p->f);
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
/*
kernel void test(global Particle * particle){
    
}*/