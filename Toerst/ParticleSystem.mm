//
//  ParticleSystem.m
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//

#import "ParticleSystem.h"

#define TEXTURE_RES (1024)

//#define NUM_PARTICLES (1024*64)
//#define NUM_PARTICLES (1024*1024*3)
#define NUM_PARTICLES (1024*500)

/*

typedef struct{
	ofVec2f vel;
	float mass;
	float dummy;		// need this to make sure the float2 vel is aligned to a 16 byte boundary
} Particle;*/

float * createBlurMask(float sigma, int * maskSizePointer) {
    int maskSize = (int)ceil(3.0f*sigma);
    float * mask = new float[(maskSize*2+1)*(maskSize*2+1)];
    float sum = 0.0f;
    for(int a = -maskSize; a < maskSize+1; a++) {
        for(int b = -maskSize; b < maskSize+1; b++) {
            float temp = exp(-((float)(a*a+b*b) / (2*sigma*sigma)));
            sum += temp;
            mask[a+maskSize+(b+maskSize)*(maskSize*2+1)] = temp;
        }
    }
    // Normalize the mask
    for(int i = 0; i < (maskSize*2+1)*(maskSize*2+1); i++)
        mask[i] = mask[i] / sum;
    
    *maskSizePointer = maskSize;
    
    return mask;
}


@implementation ParticleSystem
@synthesize clTime = _clTime;

-(void)initPlugin{
    firstLoop = YES;
    
    [[self addPropF:@"mouseForce"] setMaxValue:10];
    [[self addPropF:@"mouseAdd"] setMaxValue:50];
    [self addPropF:@"mouseRadius"];
    [self addPropF:@"generalDt"];
    [self addPropF:@"particleDamp"];
    [self addPropF:@"particleMinSpeed"];
    [self addPropF:@"particleFadeOutSpeed"];
    [self addPropF:@"particleFadeInSpeed"];
    [self addPropF:@"textureForce"];
    [self addPropB:@"drawTexture"];
    [self addPropB:@"drawForceTexture"];

    [[self addPropF:@"forceTextureForce"] setMaxValue:2.0];
    [[self addPropF:@"forceTextureBlur"] setMaxValue:1.0];
    [self addPropF:@"forceTextureMaxForce"];
    
    
 
}

-(void)setup{
    glewInit();
    
    ParticleVBO	*			particlesVboData;
    Particle *			particles;
    
    particlesVboData = (ParticleVBO*) malloc(NUM_PARTICLES* sizeof(ParticleVBO));
    particles = (Particle*) malloc(NUM_PARTICLES* sizeof(Particle));
    
    for(int i=0; i<NUM_PARTICLES; i++) {
		Particle &p = particles[i];
		p.vel.s[0] = 0;//ofRandom(-1,1);
		p.vel.s[1] = 0;//ofRandom(-1,1);
		p.mass = ofRandom(0.5, 1);

        p.dead = YES;
        
	//	particlesPos[i] = ofVec2f(ofRandom(1), ofRandom(1));
        particlesVboData[i].pos.s[0] = -1;
        particlesVboData[i].pos.s[1] = -1;
        particlesVboData[i].color.s[0] = 0.5;
        particlesVboData[i].color.s[1] = 0.5;
        particlesVboData[i].color.s[2] = 0.0;
        particlesVboData[i].color.s[3] = 0.5;
    }
    
    
    
    //VBO
    glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
//	glBufferData(GL_ARRAY_BUFFER, sizeof(ParticleVBO) * NUM_PARTICLES, particlesVboData, GL_DYNAMIC_COPY);
    	glBufferData(GL_ARRAY_BUFFER, sizeof(ParticleVBO) * NUM_PARTICLES, particlesVboData, GL_STATIC_DRAW);
//	glBufferData(GL_ARRAY_BUFFER, sizeof(ParticleVBO) * NUM_PARTICLES, particlesVboData, GL_STREAM_DRAW);
    
	glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    
    float * textureData = (float*) malloc(sizeof(float)*TEXTURE_RES*TEXTURE_RES*3);
    memset(textureData, 1.0, TEXTURE_RES*TEXTURE_RES*3*sizeof(float));

    glGenTextures( 1, &texture );
    glBindTexture(GL_TEXTURE_2D,texture); // Set our Tex handle as current
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,TEXTURE_RES,TEXTURE_RES,0,GL_RGB,GL_FLOAT,textureData);


    glGenTextures( 1, &forceTexture );
    glBindTexture(GL_TEXTURE_2D,forceTexture); // Set our Tex handle as current
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,TEXTURE_RES,TEXTURE_RES,0,GL_RGB,GL_FLOAT,textureData);

   /* glGenTextures( 1, &texture_blur );
    glBindTexture(GL_TEXTURE_2D,texture_blur); // Set our Tex handle as current
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,TEXTURE_RES,TEXTURE_RES,0,GL_RGB,GL_FLOAT,textureData);
    
    
    glGenTextures( 1, &forceTexture_blur );
    glBindTexture(GL_TEXTURE_2D,forceTexture_blur); // Set our Tex handle as current
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,TEXTURE_RES,TEXTURE_RES,0,GL_RGB,GL_FLOAT,textureData);
    
    
   */ 
    
    
    //Shared context
    CGLContextObj cgl_context = CGLGetCurrentContext();
    CGLShareGroupObj sharegroup = CGLGetShareGroup(cgl_context);
    gcl_gl_set_sharegroup(sharegroup);
    
    // Create a CL dispatch queue.
    queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_GPU, NULL);
    // Create a dispatch semaphore used for CL / GL sharing.
    cl_gl_semaphore = dispatch_semaphore_create(0);
    
    pos_gpu = (ParticleVBO*)gcl_gl_create_ptr_from_buffer(vbo);

    texture_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, texture);
    forceTexture_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, forceTexture);
    //    texture_blur_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, texture_blur);
    //    forceTexture_blur_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, forceTexture_blur);

    
    particle_gpu  = (Particle*)gcl_malloc(sizeof(Particle) * NUM_PARTICLES, particles,
          CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR);
    
    
    countCache_gpu = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES,  nil, CL_MEM_READ_WRITE );
    forceCache_gpu = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES*2,  nil, CL_MEM_READ_WRITE );
    forceCacheBlur_gpu = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES*2,  nil, CL_MEM_READ_WRITE );
    
    float * mask =createBlurMask(1.2f, &maskSize);
    cout<<"Mask size: "<<maskSize<<endl;
    mask_gpu = (cl_float*) gcl_malloc(sizeof(cl_float)*(maskSize*2+1)*(maskSize*2+1),  mask, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR);
    

    dispatch_async(queue,
                   ^{
                       gcl_memcpy(pos_gpu, (ParticleVBO*)particlesVboData, sizeof(ParticleVBO)*NUM_PARTICLES);
                       gcl_memcpy(mask_gpu, mask, sizeof(cl_float)*(maskSize*2+1)*(maskSize*2+1));

                   });
    
    
    
    cl_device_id cl_device = gcl_get_device_id_with_dispatch_queue(queue);
    char name[128];
    char vendor[128];
    clGetDeviceInfo(cl_device, CL_DEVICE_NAME, 128, name, NULL);
    clGetDeviceInfo(cl_device, CL_DEVICE_VENDOR, 128, vendor, NULL);
    fprintf(stdout, "%s : %s\n", vendor, name);

    size_t work_item_size;
    clGetDeviceInfo(cl_device, CL_DEVICE_MAX_WORK_ITEM_SIZES, sizeof(work_item_size), &work_item_size, NULL);
    printf("Mac device work item sizes: %lu", work_item_size);
//    clGetDeviceInfo(cl_device, CL_DEVICE_MAX_WORK_ITEM_SIZES, sizeof(work_item_size), work_item_size, NULL);
   // clGetDeviceInfo(cl_device, CL_DEVICE_MAX_WORK_ITEM_SIZES)
    
    
    
}

int curr_read_index, curr_write_index;

-(void)update:(NSDictionary *)drawingInformation{
   


}

-(void)draw:(NSDictionary *)drawingInformation{
    vector<ofVec2f> trackers = [GetPlugin(OSCControl) getTrackerCoordinates];
    
    CachePropF(mouseForce);
    CachePropF(mouseRadius);
    CachePropF(mouseAdd);
    
    CachePropF(particleDamp);
    CachePropF(generalDt);
    CachePropF(particleMinSpeed);
    CachePropF(particleFadeOutSpeed);
    CachePropF(particleFadeInSpeed);
    
    CachePropF(textureForce);
    
    CachePropF(forceTextureForce);
    CachePropF(forceTextureMaxForce);
    CachePropB(drawForceTexture);
    CachePropF(forceTextureBlur);
    //    float * clear = (float*)malloc(sizeof(float)*TEXTURE_RES*TEXTURE_RES*4);
    
    //dispatch_group_t group = dispatch_group_create();
    // dispatch_group_enter(group);

    dispatch_async(queue,
                   ^{
                       cl_ndrange ndrange = {
                           1,                     // The number of dimensions to use.
                           {0, 0, 0},
                           {NUM_PARTICLES, 0, 0},
                           {0}
                       };
                       cl_ndrange ndrangeGaus = {
                           2,
                           {0, 0, 0},
                           {TEXTURE_RES, TEXTURE_RES},
                           {0}
                       };
                       
         
                    
                       sumParticles_kernel(&ndrange, particle_gpu, pos_gpu, countCache_gpu, forceCache_gpu,  TEXTURE_RES);
                       if(forceTextureBlur){
                           gaussianBlurSum_kernel(&ndrangeGaus,  forceCache_gpu, forceCacheBlur_gpu, TEXTURE_RES, mask_gpu, maskSize);
                       }
                       //------------------
                       // Forces
                       //------------------
                       
                       if(textureForce){
                           textureForce_kernel(&ndrange, particle_gpu, pos_gpu, texture_gpu, textureForce*0.1);
                       }
                       if(forceTextureForce){
                           if(forceTextureBlur){
                           forceTextureForce_kernel(&ndrange, particle_gpu, pos_gpu, forceCacheBlur_gpu, forceTextureForce*0.01, forceTextureMaxForce, TEXTURE_RES);
                           } else {
                               forceTextureForce_kernel(&ndrange, particle_gpu, pos_gpu, forceCache_gpu, forceTextureForce*0.01, forceTextureMaxForce, TEXTURE_RES);
                               
                           }
                       }
                       
                       for(int i=0;i<trackers.size();i++){
                           cl_float2 mousePos;
                           mousePos.s[0] = trackers[i].y;
                           mousePos.s[1] = 1-trackers[i].x;
                           if(mouseForce){
                               mouseForce_kernel(&ndrange, (Particle*)particle_gpu, pos_gpu, mousePos , mouseForce*0.1, mouseRadius*0.3);
                           }
                           
                           float n = 10.0f;
                           if(mouseAdd){
                               cl_ndrange ndrangeMouse = {
                                   1,                     // The number of dimensions to use.
                                   {0, 0, 0},
                                   {n, 0, 0},
                                   {0}
                               };
                               
                               mouseAdd_kernel(&ndrangeMouse, particle_gpu, pos_gpu, mousePos, mouseRadius, mouseAdd, NUM_PARTICLES);
                           }
                       }
                       
                       update_kernel(&ndrange, (Particle*)particle_gpu, pos_gpu , generalDt* 1.0/60.0, 1.0-particleDamp, particleMinSpeed, particleFadeInSpeed*0.01 ,particleFadeOutSpeed*0.01);

                       
                       //dispatch_group_leave(group);
                       
                       
                       cl_ndrange ndrangeTex = {
                           2,
                           {0, 0, 0},
                           {TEXTURE_RES, TEXTURE_RES},
                           {32,32,0}
                       };
                       cl_ndrange ndrangeTexNDef = {
                           2,
                           {0, 0, 0},
                           {TEXTURE_RES, TEXTURE_RES},
                           {}
                       };

                       

                       if(textureForce){
                           //  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
                           
                           updateTexture_kernel(&ndrangeTex, texture_gpu, pos_gpu, NUM_PARTICLES, 1024*sizeof(int), countCache_gpu );
                           //gaussian_blur_kernel(&ndrangeTexNDef, texture_gpu, mask_gpu, texture_blur_gpu, maskSize);
                           
                       }
                       
                       if(drawForceTexture){
                           updateForceTexture_kernel(&ndrangeTex, forceTexture_gpu, forceCacheBlur_gpu);
                       }

                       
                       
                       cl_ndrange ndrangeReset = {
                           1,
                           {0, 0, 0},
                           {TEXTURE_RES*TEXTURE_RES},
                           {0}
                       };
                       
                       resetCountCache_kernel(&ndrangeReset, countCache_gpu, forceCache_gpu);
                                              
                       dispatch_semaphore_signal(cl_gl_semaphore);
                       
                   });
    // Queue CL kernel to dispatch queue.
    
    // if(!firstLoop)
    dispatch_semaphore_wait(cl_gl_semaphore, DISPATCH_TIME_FOREVER);
    
    ofEnableAlphaBlending();
    
    if(PropB(@"drawTexture")){
        ofSetColor(255, 255, 255);
        
        glEnable( GL_TEXTURE_2D );
        glBindTexture( GL_TEXTURE_2D, texture );
        glBegin(GL_QUADS);
        
        glTexCoord2d(0.0,0.0); glVertex2d(0.0,0.0);
        glTexCoord2d(1.0,0.0); glVertex2d(1.0,0.0);
        glTexCoord2d(1.0,1.0); glVertex2d(1.0,1.0);
        glTexCoord2d(0.0,1.0); glVertex2d(0.0,1.0);
        glEnd();
        glDisable(GL_TEXTURE_2D);
        
    } else if(PropB(@"drawForceTexture")){
        ofSetColor(255, 255, 255);
        
        glEnable( GL_TEXTURE_2D );
        glBindTexture( GL_TEXTURE_2D, forceTexture);
        glBegin(GL_QUADS);
        
        glTexCoord2d(0.0,0.0); glVertex2d(0.0,0.0);
        glTexCoord2d(1.0,0.0); glVertex2d(1.0,0.0);
        glTexCoord2d(1.0,1.0); glVertex2d(1.0,1.0);
        glTexCoord2d(0.0,1.0); glVertex2d(0.0,1.0);
        glEnd();
        glDisable(GL_TEXTURE_2D);
        
    }
    NSDate * time = [NSDate date];
    
//   ofSetColor(255, 255, 255, 100);
    glBindBufferARB(GL_ARRAY_BUFFER_ARB, vbo);

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
	glVertexPointer(2, GL_FLOAT,  sizeof(ParticleVBO), (char *) NULL );
    glColorPointer(4, GL_FLOAT, sizeof(ParticleVBO),(char *) NULL + 4*sizeof(GLfloat));
	glDrawArrays(GL_POINTS, 0, NUM_PARTICLES);
    
    glDisableClientState(GL_COLOR_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);

	glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
 
    self.clTime =  1000.0*[time timeIntervalSinceNow];

    
    //   vector<ofVec2f> trackers = [GetPlugin(OSCControl) getTrackerCoordinates];
    ofSetColor(100, 100, 100);
    for(int i=0;i<trackers.size();i++){
        ofCircle(trackers[i].y, 1-trackers[i].x, 0.01);
    }
    
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    /*if(object == Prop(@"forceTextureBlur")){
        int maskSize_;
        float * mask =createBlurMask(10.0*PropF(@"forceTextureBlur"), &maskSize_);
        cout<<"Mask size: "<<maskSize_<<endl;
        if(queue){
            
            dispatch_sync(queue,
                           ^{
                               maskSize = maskSize_;
                               gcl_memcpy(mask_gpu, mask, sizeof(cl_float)*(maskSize*2+1)*(maskSize*2+1));
                               
                           });
        }
    }*/
}

@end
