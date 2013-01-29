//
//  ParticleSystem.m
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//

#import "ParticleSystem.h"
#import <ofxCocoaPlugins/Keystoner.h>
#import <ofxCocoaPlugins/BlobTracker2d.h>

#define TEXTURE_RES (1024)

//#define NUM_PARTICLES (1024*64)
//#define NUM_PARTICLES (1024*10+24*3)
#define NUM_PARTICLES (1024*1024)
#define NUM_PARTICLES_FRAC  MAX(1024, (NUM_PARTICLES * (  floor(PropF(@"generalUpdateFraction") * 1024)/1024.0)))
#define NUM_BLOB_POINTS 300


static NSString *totalIdentifier = @"Total";
static NSString *updateIdentifier = @"Update";
static NSString *updateTextureIdentifier = @"Update Texture";
static NSString *sumIdentifier = @"Sum";
static NSString *forceIdentifier = @"Forces";
static NSString *addIdentifier = @"Add";
static NSString *passiveIdentifier = @"Passive";
static NSString *inactiveIdentifier = @"Inactive Particles";
static NSString *activeIdentifier = @"Active Particles";
static NSString *deadIdentifier = @"Dead Particles";



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
@synthesize plotData = _plotData;

-(void)initPlugin{
    firstLoop = YES;
    [self addPropB:@"_debug"];
    [self addPropB:@"passiveParticles"];
    [[self addPropF:@"passiveMultiplier"] setMinValue:0.01 maxValue:1.0];
    [[self addPropF:@"passiveBlur"] setMaxValue:0.1];
    [[self addPropF:@"passiveFade"] setMinValue:0.9 maxValue:1.0];
    [self addPropB:@"loadImage"];
    
    [[self addPropF:@"mouseForce"] setMaxValue:10];
    [[self addPropF:@"mouseAdd"] setMaxValue:100.0];
    [self addPropF:@"mouseRadius"];
    [self addPropF:@"generalDt"];
    [[self addPropF:@"generalUpdateFraction"] setMinValue:0.1 maxValue:1.0];
    [Prop(@"generalUpdateFraction") setDefaultValue:@(1)];
    
    [self addPropF:@"particleDamp"];
    [self addPropF:@"particleMinSpeed"];
    [self addPropF:@"particleFadeOutSpeed"];
    [[self addPropF:@"particleFadeInSpeed"] setMaxValue:1000.0];
    [[self addPropF:@"densityForce"] setMaxValue:0.05];
    [self addPropB:@"drawTexture"];
    [self addPropB:@"drawForceTexture"];
    
    [self addPropF:@"forceFieldParticleInfluence"];
    [[self addPropF:@"forceTextureForce"] setMaxValue:10.0];
    //    [[self addPropF:@"forceTextureBlur"] setMaxValue:1.0];
    [self addPropF:@"forceTextureMaxForce"];
    
    [[self addPropF:@"lightX"] setMinValue:-1 maxValue:1];
    [[self addPropF:@"lightY"] setMinValue:-1 maxValue:1];
    [[self addPropF:@"lightZ"] setMinValue:-1 maxValue:1];
    [self addPropF:@"shaderDiffuse"] ;
    [[self addPropF:@"shaderGain"] setMaxValue:10.0];
    
    [[self addPropF:@"globalWindX"] setMinValue:-1000 maxValue:1000];
    [[self addPropF:@"globalWindY"] setMinValue:-1000 maxValue:1000];
    [[self addPropF:@"globalWind"] setMinValue:0 maxValue:1];
    
    [[self addPropF:@"pointWindX"] setMinValue:0 maxValue:1];
    [[self addPropF:@"pointWindY"] setMinValue:0 maxValue:1];
    [[self addPropF:@"pointWind"] setMinValue:0 maxValue:1000];
    
    
    [[self addPropF:@"rectAddX"] setMinValue:0 maxValue:1];
    [[self addPropF:@"rectAddY"] setMinValue:0 maxValue:1];
    [[self addPropF:@"rectAddWidth"] setMinValue:0 maxValue:1];
    [[self addPropF:@"rectAddHeight"] setMinValue:0 maxValue:1];
    [[self addPropF:@"rectAdd"] setMinValue:0 maxValue:500];
    
    
    [[self addPropF:@"whirlAmount"] setMinValue:0 maxValue:1];
    [[self addPropF:@"whirlRadius"] setMinValue:0 maxValue:1];
    [[self addPropF:@"whirlX"] setMinValue:0 maxValue:1];
    [[self addPropF:@"whirlY"] setMinValue:0 maxValue:1];
    [[self addPropF:@"whirlGravity"] setMinValue:0 maxValue:1];
    [[self addPropF:@"stickyAmount"] setMinValue:0 maxValue:1];
    [[self addPropF:@"stickyGain"] setMinValue:0 maxValue:1];
    
    [[self addPropF:@"opticalFlow"] setMinValue:0 maxValue:1];
    
}



-(void)setup{
    glewInit();
    
    //    ParticleVBO	*			particlesVboData;
    Particle *			particles;
    
    // particlesVboData = (ParticleVBO*) malloc(NUM_PARTICLES* sizeof(ParticleVBO));
    particles = (Particle*) malloc(NUM_PARTICLES* sizeof(Particle));
    counter = (ParticleCounter*) malloc(sizeof(ParticleCounter));
    
    
    cout<<"Particle size: "<<sizeof(Particle)<<endl;
    
    for(int i=0; i<NUM_PARTICLES; i++) {
		Particle &p = particles[i];
		p.vel.s[0] = 0;//ofRandom(-1,1);
		p.vel.s[1] = 0;//ofRandom(-1,1);
		p.mass = ofRandom(0.5, 1);
        p.pos.s[0] = ofRandom(1);
        p.pos.s[1] = ofRandom(1);
        p.dead = YES;
        p.inactive = NO;
        p.alpha = 0.0;
        p.layer = 0;
        
        //	particlesPos[i] = ofVec2f(ofRandom(1), ofRandom(1));
        /*        particlesVboData[i].pos.s[0] = -1;
         particlesVboData[i].pos.s[1] = -1;*/
        /*   particlesVboData[i].pos.s[0] = p.pos.s[0];
         particlesVboData[i].pos.s[1] = p.pos.s[1];
         particlesVboData[i].color.s[0] = 1;
         particlesVboData[i].color.s[1] = 1;
         particlesVboData[i].color.s[2] = 1;
         particlesVboData[i].color.s[3] = 0.5;*/
    }
    
    isDead = (cl_uint*)malloc(sizeof(cl_uint)*NUM_PARTICLES/32);
    for(int i=0;i<NUM_PARTICLES/32;i++){
        isDead[i] = 0xFFFFFFFF;
        //        isDead[i] = 0x0;
    }
    
    
    counter->activeParticles = 0;
    counter->deadParticles = 0;
    counter->inactiveParticles = 0;
    
    
    
    //VBO
/*    glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
    //	glBufferData(GL_ARRAY_BUFFER, sizeof(ParticleVBO) * NUM_PARTICLES, particlesVboData, GL_DYNAMIC_COPY);
    // glBufferData(GL_ARRAY_BUFFER, sizeof(ParticleVBO) * NUM_PARTICLES, particlesVboData, GL_STATIC_DRAW);
    //	glBufferData(GL_ARRAY_BUFFER, sizeof(ParticleVBO) * NUM_PARTICLES, particlesVboData, GL_STREAM_DRAW);
    
	glBindBuffer(GL_ARRAY_BUFFER, 0);
    */
    
    float * textureData = (float*) malloc(sizeof(float)*TEXTURE_RES*TEXTURE_RES*3);
    memset(textureData, 1.0, TEXTURE_RES*TEXTURE_RES*3*sizeof(float));
    
    glGenTextures( 1, &texture[0] );
    glBindTexture(GL_TEXTURE_2D,texture[0]); // Set our Tex handle as current
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,TEXTURE_RES,TEXTURE_RES,0,GL_RGB,GL_FLOAT,textureData);
    
    glGenTextures( 1, &texture[1] );
    glBindTexture(GL_TEXTURE_2D,texture[1]); // Set our Tex handle as current
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
    
    glGenTextures( 1, &texture_blur );
    glBindTexture(GL_TEXTURE_2D,texture_blur); // Set our Tex handle as current
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,TEXTURE_RES,TEXTURE_RES,0,GL_RGB,GL_FLOAT,textureData);
    
    /*
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
    queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_GPU  , NULL);
    // Create a dispatch semaphore used for CL / GL sharing.
    cl_gl_semaphore = dispatch_semaphore_create(0);
    
    // pos_gpu = (ParticleVBO*)gcl_gl_create_ptr_from_buffer(vbo);
    
    texture_gpu[0]      = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, texture[0]);
    texture_gpu[1]      = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, texture[1]);
    forceTexture_gpu    = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, forceTexture);
    texture_blur_gpu    = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, texture_blur);
    //    forceTexture_blur_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, forceTexture_blur);
    
    particle_gpu            = (Particle*)gcl_malloc(sizeof(Particle) * NUM_PARTICLES, particles, CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR);
    
    isDead_gpu              = (cl_uint*)gcl_malloc(sizeof(cl_uint)*NUM_PARTICLES/32, isDead, CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR);
    
    countInactiveBuffer_gpu = (cl_uint*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES,  nil, CL_MEM_READ_WRITE );
    countActiveBuffer_gpu   = (cl_uint*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES,  nil, CL_MEM_READ_WRITE );
    countPassiveBuffer_gpu  = (PassiveType*) gcl_malloc(sizeof(PassiveType)*TEXTURE_RES*TEXTURE_RES,  nil, CL_MEM_READ_WRITE );
    countCreateParticleBuffer_gpu = (cl_uint*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES,  nil, CL_MEM_READ_WRITE );
    
    stickyBuffer_gpu        = (cl_uchar*) gcl_malloc(sizeof(cl_uchar)*TEXTURE_RES*TEXTURE_RES,  nil, CL_MEM_READ_WRITE );
    
    bodyBlob_gpu            = (cl_int*) gcl_malloc(sizeof(cl_int)*NUM_BLOB_POINTS*2,  nil, CL_MEM_READ_ONLY );
    
    for(int i=0;i<2;i++){
        bodyField_gpu[i]    = (BodyType*) gcl_malloc(sizeof(BodyType)*(TEXTURE_RES/BodyDivider)*(TEXTURE_RES/BodyDivider)*3,  nil, CL_MEM_READ_WRITE );
    }
    //    bodyField_gpu[1]           = (BodyType*) gcl_malloc(sizeof(BodyType)*TEXTURE_RES*TEXTURE_RES*3,  nil, CL_MEM_READ_WRITE );
    
    forceField_gpu          = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES*2,  nil, CL_MEM_READ_WRITE );
    forceCacheBlur_gpu      = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES*2,  nil, CL_MEM_READ_WRITE );
    
    
    opticalFlow_gpu         = (cl_int*) gcl_malloc(sizeof(cl_int)*(OpticalFlowSize)*(OpticalFlowSize)*2,  nil, CL_MEM_READ_ONLY );
    
    counter_gpu             = (ParticleCounter*) gcl_malloc(sizeof(ParticleCounter),  nil, CL_MEM_READ_WRITE );
    
    float * mask =createBlurMask(0.5f, &maskSize);
    cout<<"Mask size: "<<maskSize<<endl;
    mask_gpu                        = (cl_float*) gcl_malloc(sizeof(cl_float)*(maskSize*2+1)*(maskSize*2+1),  mask, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR);
    
    dispatch_async(queue,
                   ^{
                       //  gcl_memcpy(pos_gpu, (ParticleVBO*)particlesVboData, sizeof(ParticleVBO)*NUM_PARTICLES);
                       gcl_memcpy(mask_gpu, mask, sizeof(cl_float)*(maskSize*2+1)*(maskSize*2+1));
                       gcl_memcpy(counter_gpu, counter, sizeof(ParticleCounter));
                       gcl_memcpy(isDead_gpu, isDead, sizeof(cl_int)*(NUM_PARTICLES/32));
                   });
    
    cl_device_id cl_device = gcl_get_device_id_with_dispatch_queue(queue);
    char name[128];
    char vendor[128];
    clGetDeviceInfo(cl_device, CL_DEVICE_NAME, 128, name, NULL);
    clGetDeviceInfo(cl_device, CL_DEVICE_VENDOR, 128, vendor, NULL);
    fprintf(stdout, "%s : %s\n", vendor, name);
    
    size_t work_item_size;
    clGetDeviceInfo(cl_device, CL_DEVICE_MAX_WORK_ITEM_SIZES, sizeof(work_item_size), &work_item_size, NULL);
    
    cl_ulong size;
    clGetDeviceInfo(cl_device, CL_DEVICE_LOCAL_MEM_SIZE, sizeof(cl_ulong), &size, 0);
    
    
    
    printf("Mac device work item sizes: %lu  -  max local memory: %llu bytes (%llu ints) \n", work_item_size, size, size/sizeof(cl_int));
    //    clGetDeviceInfo(cl_device, CL_DEVICE_MAX_WORK_ITEM_SIZES, sizeof(work_item_size), work_item_size, NULL);
    // clGetDeviceInfo(cl_device, CL_DEVICE_MAX_WORK_ITEM_SIZES)
    diffuse = [[Shader alloc] initWithShadersInAppBundle:@"diffuse"];
    if(diffuse){
        programObject = [diffuse programObject];
        
        glUseProgramObjectARB(programObject);
        shaderLocations[0] = [diffuse getUniformLocation:"light"];
        shaderLocations[1] = [diffuse getUniformLocation:"gain"];
        shaderLocations[2] = [diffuse getUniformLocation:"diffuse"];
        
        glUseProgramObjectARB(NULL);
        
    }
    
    
    
    
    {
        ofImage image;
        image.setUseTexture(false);
        bool loaded =  image.loadImage("/Users/recoil/Documents/Produktioner/Tørst/background/sticky.png");
        NSLog(@"Loaded image %ix%i %i",image.width,image.height,image.type);
        
        if(loaded){
            unsigned char * pixelsDst = (unsigned char*)malloc(sizeof(unsigned char)*TEXTURE_RES*TEXTURE_RES);
            
            for(int i=0;i<TEXTURE_RES*TEXTURE_RES;i++){
                pixelsDst[i] = image.getPixelsRef()[i];
            }
            
            dispatch_async(queue,
                           ^{
                               gcl_memcpy(stickyBuffer_gpu, pixelsDst, sizeof(cl_uchar)*TEXTURE_RES*TEXTURE_RES);
                               delete pixelsDst;
                           });
        }
        
    }
}

int curr_read_index, curr_write_index;

-(void)update:(NSDictionary *)drawingInformation{
    
    
    
}

static dispatch_once_t onceToken;
-(void)draw:(NSDictionary *)drawingInformation{
    
    CachePropF(mouseForce);
    CachePropF(mouseRadius);
    CachePropF(mouseAdd);
    
    CachePropF(rectAdd);
    CachePropF(rectAddX);
    CachePropF(rectAddY);
    CachePropF(rectAddWidth);
    CachePropF(rectAddHeight);
    
    CachePropF(particleDamp);
    CachePropF(generalDt);
    CachePropF(particleMinSpeed);
    CachePropF(particleFadeOutSpeed);
    CachePropF(particleFadeInSpeed);
    
    CachePropF(densityForce);
    
    CachePropF(forceTextureForce);
    CachePropF(forceFieldParticleInfluence);
    
    CachePropF(forceTextureMaxForce);
    CachePropB(drawForceTexture);
    CachePropF(opticalFlow);
    
    if(PropB(@"loadImage")){
        SetPropB(@"loadImage",false);
        
        ofImage image;
        image.setUseTexture(false);
        bool loaded =  image.loadImage("/Users/recoil/Documents/Produktioner/Tørst/background/background.png");
        NSLog(@"Loaded image %ix%i %i",image.width,image.height,image.type);
        
        if(loaded){
            unsigned int * pixelsDst = (unsigned int*)malloc(sizeof(unsigned int)*TEXTURE_RES*TEXTURE_RES);
            for(int i=0;i<TEXTURE_RES*TEXTURE_RES;i++){
                pixelsDst[i] = image.getPixelsRef()[i*4];
            }
            
            dispatch_async(queue,
                           ^{
                               gcl_memcpy(countPassiveBuffer_gpu, pixelsDst, sizeof(PassiveType)*TEXTURE_RES*TEXTURE_RES);
                               delete pixelsDst;
                           });
        }
    }
    
    
    vector<ofVec2f> trackers = [GetPlugin(OSCControl) getTrackerCoordinates];
    
    
    dispatch_once(&onceToken, ^{
        bodyBlobData = (int*)malloc(sizeof(int)*NUM_BLOB_POINTS*2);
        opticalFlowData = (int*)malloc(sizeof(int)*OpticalFlowSize*OpticalFlowSize*2);
    });
    
    vector<ofVec2f> trackerPoints;
    
    if(trackers.size()> 0){
        for(int i=0;i<50;i++){
            float a = i/(float)50;
            ofVec2f p = ofVec2f(sin(a*TWO_PI), cos(a*TWO_PI))*20* (sin(a*TWO_PI*4)+3) + 1024*ofVec2f(trackers[0].y,1-trackers[0].x);
            
            p.x = MAX(0,p.x);
            p.x = MIN(1024,p.x);
            p.y = MAX(0,p.y);
            p.y = MIN(1024,p.y);
            
            trackerPoints.push_back(p);
        }
    }

    
    if(opticalFlow){
        BlobTrackerInstance2d * trackerInstance = [GetPlugin(BlobTracker2d) getInstance:0];
        NSLog(@"Sizeeeee   %i %i",[trackerInstance opticalFlowW], [trackerInstance opticalFlowH]);
        
        if([trackerInstance opticalFlowW] == OpticalFlowSize && [trackerInstance opticalFlowH] == OpticalFlowSize){
            
            ofVec2f * _opticalFlowData = [trackerInstance opticalFlowFieldCalibrated];
             for(int i=0;i<OpticalFlowSize*OpticalFlowSize;i++){
                opticalFlowData[i*2] = _opticalFlowData[i].x;
                opticalFlowData[i*2+1] = _opticalFlowData[i].y;
            }
            
           dispatch_sync(queue,
                           ^{
                               gcl_memcpy(opticalFlow_gpu, opticalFlowData, sizeof(int)*OpticalFlowSize*OpticalFlowSize*2);
                           });
        }
        
        //[ opticalFlowFieldCalibrated]->
    }
    
    

    
    dispatch_sync(queue,
                  ^{
                      //Reset counters
                      counter->deadParticles = 0; counter->activeParticles = 0; counter->inactiveParticles = 0; counter->deadParticlesBit = 0;
                      gcl_memcpy(counter_gpu, counter, sizeof(ParticleCounter));
                      
                      //Start timer
                      cl_timer totalTimer = gcl_start_timer();
                      
                      
                      //Ranges
                      cl_ndrange ndrange = {
                          1,
                          {0, 0, 0},
                          {NUM_PARTICLES_FRAC, 0, 0},
                          {0}
                      };
                 /*     cl_ndrange ndrange32 = {
                          1,
                          {0, 0, 0},
                          {NUM_PARTICLES_FRAC/32, 0, 0},
                          {0}
                      };
                      */
                      cl_ndrange ndrangeTex = {
                          2,
                          {0, 0, 0},
                          {TEXTURE_RES, TEXTURE_RES},
                          {0}
                      };
                      cl_ndrange ndrangeTexAdd = {
                          1,
                          {0, 0, 0},
                          {TEXTURE_RES*TEXTURE_RES},
                          {0}
                      };
                      
                      
                      /*if(forceTextureBlur){
                       gaussianBlurSum_kernel(&ndrangeGaus,  forceField_gpu, forceCacheBlur_gpu, TEXTURE_RES, mask_gpu, maskSize);
                       }*/
                      
                      
                      //------------------
                      //BODY
                      //------------------
                      int minX, maxX, minY, maxY;
                      minX = maxX = minY = maxY = -1;
                   
                      if(trackerPoints.size()> 0){
                          cl_timer bodyTimer = gcl_start_timer();
                          
                          
                          for(int i=0;i<trackerPoints.size();i++){
                              bodyBlobData[i*2] = trackerPoints[i].x;
                              bodyBlobData[i*2+1] = trackerPoints[i].y;
                              
                              if(trackerPoints[i].x < minX || minX == -1)
                                  minX = trackerPoints[i].x;
                              if(trackerPoints[i].x > maxX || maxX == -1)
                                  maxX = trackerPoints[i].x;
                              if(trackerPoints[i].y < minY || minY == -1)
                                  minY = trackerPoints[i].y;
                              if(trackerPoints[i].y > maxY || maxY == -1)
                                  maxY = trackerPoints[i].y;
                          }
                          
                          minX = floor(minX / 64.0f)*64.0/BodyDivider;
                          minY = floor(minY / 64.0f)*64.0/BodyDivider;
                          
                          maxX = ceil(maxX / 64.0f)*64.0/BodyDivider;
                          maxY = ceil(maxY / 64.0f)*64.0/BodyDivider;
                          
                          
                        //  NSLog(@"%i %i %i %i",minX,maxX,minY,maxY);
                          cl_ndrange ndrangeBody = {
                              2,
                              {minX, minY, 0},
                              {maxX-minX, maxY-minY},
                              {0}
                          };
                          
                          cl_ndrange ndrangeBody2 = {
                              2,
                              {minX*BodyDivider, minY*BodyDivider, 0},
                              {(maxX-minX)*BodyDivider, (maxY-minY)*BodyDivider},
                              {0}
                          };
                          
                          
                          //   NSLog(@"Step 0 %f",gcl_stop_timer(bodyTimer));
                          bodyTimer = gcl_start_timer();
                          
                         
                          gcl_memcpy(bodyBlob_gpu, bodyBlobData, sizeof(int)*trackerPoints.size()*2);
                          
                          updateBodyFieldStep1_kernel(&ndrangeBody, bodyField_gpu[0], bodyBlob_gpu, trackerPoints.size());
                        
                          // NSLog(@"Step 1 %f",gcl_stop_timer(bodyTimer));
                          bodyTimer = gcl_start_timer();
                        
                        
                          bool flip = false;
                          for(int i=0;i<40;i++){
                              updateBodyFieldStep2_kernel(&ndrangeBody, bodyField_gpu[flip], bodyField_gpu[!flip],i, sizeof(int)*1024);
                              flip = !flip;
                          }
                          // NSLog(@"Step 2 %f",gcl_stop_timer(bodyTimer));
                          bodyTimer = gcl_start_timer();
                          
                          
                          updateBodyFieldStep3_kernel(&ndrangeBody2, bodyField_gpu[flip], forceField_gpu, mouseForce*0.1);
                          
                          //   NSLog(@"Step 3 %f",gcl_stop_timer(bodyTimer));
                          //bodyTimer = gcl_start_timer();
                        
                          
                      }
                      
                      //------------------
                      // Forces
                      //------------------
                      
                      
                      //############### FORCE ##############
                      cl_timer forceTimer = gcl_start_timer();
                      
                      if(densityForce){
                          gaussianBlurImage_kernel(&ndrangeTex, texture_gpu[textureFlipFlop], mask_gpu, texture_gpu[!textureFlipFlop], maskSize);
                          
                          textureDensityForce_kernel(&ndrange, particle_gpu, texture_gpu[!textureFlipFlop], densityForce*0.1);
                      }
                      
                      
                      for(int i=0;i<trackers.size();i++){
                          cl_float2 mousePos;
                          mousePos.s[0] = trackers[i].y;
                          mousePos.s[1] = 1-trackers[i].x;
                          if(mouseForce){
//                           mouseForce_kernel(&ndrangeTex, forceField_gpu, mousePos , mouseForce*0.1, mouseRadius*0.3);
                           }
                          
                          if(mouseAdd){
                              mouseAdd_kernel(&ndrangeTex, countCreateParticleBuffer_gpu, mousePos, mouseRadius, mouseAdd);
                          }
                      }
                      
                      if(rectAdd){
                          cl_float4 rect;
                          rect.s[0] = rectAddX;
                          rect.s[1] = rectAddY;
                          rect.s[2] = rectAddWidth;
                          rect.s[3] = rectAddHeight;
                          rectAdd_kernel(&ndrangeTex, countPassiveBuffer_gpu, rect, rectAdd);
                          //rectAdd_kernel(&ndrangeAdd, particle_gpu, rect, roundf(rectAdd), NUM_PARTICLES_FRAC, ofRandom(0,1), ofRandom(0,1));
                          
                      }
                      
                      if(opticalFlow){
                          cl_ndrange ndrangeOptical = {
                              2,
                              {0,0, 0},
                              {50-1,50-1},
                              {0}
                          };
                          
                          opticalFlow_kernel(&ndrangeOptical, opticalFlow_gpu, forceField_gpu, 20, opticalFlow);
                      }
                      
                      
                      double forceTime = gcl_stop_timer(forceTimer);
                      //#############################
                      
                      
                      
                      //############### WIND ##############
                      cl_timer windTimer = gcl_start_timer();
                      if(PropF(@"globalWind") || PropF(@"pointWind")){
                          ofVec2f * globalWind = new ofVec2f(PropF(@"globalWindX")*PropF(@"globalWind"), PropF(@"globalWindY")*PropF(@"globalWind"));
                          
                          ofVec3f * pointWind = new ofVec3f(PropF(@"pointWindX"), PropF(@"pointWindY"),PropF(@"pointWind"));
                          
                          wind_kernel(&ndrangeTex, forceField_gpu, *((cl_float2*)globalWind), *((cl_float3*)pointWind));
                          
                      }
                      if(PropF(@"whirlAmount")){
                          whirl_kernel(&ndrangeTex, forceField_gpu, PropF(@"whirlAmount"), PropF(@"whirlRadius")*1024, PropF(@"whirlX")*1024, PropF(@"whirlY")*1024, PropF(@"whirlGravity"));
                      }
                      double windTime = gcl_stop_timer(windTimer);
                      //####################################
                      
                      
                      
                      
                      
                      
                      //############# PASSIVE #############
                      cl_timer passiveTimer = gcl_start_timer();
                      
                      sumParticleActivity_kernel(&ndrange, particle_gpu,countActiveBuffer_gpu, countInactiveBuffer_gpu, TEXTURE_RES);
                     
                      if(PropB(@"passiveParticles")){
                          passiveParticlesBufferUpdate_kernel(&ndrangeTex, countPassiveBuffer_gpu, countInactiveBuffer_gpu, countActiveBuffer_gpu, countCreateParticleBuffer_gpu, forceField_gpu, PropF(@"passiveMultiplier"));
                          
                          passiveParticlesParticleUpdate_kernel(&ndrange, particle_gpu, countPassiveBuffer_gpu, TEXTURE_RES, isDead_gpu);
                          passiveWasActive = true;
                      } else if(passiveWasActive){
                          passiveWasActive = false;
                          activateAllPassiveParticles_kernel(&ndrangeTex, countPassiveBuffer_gpu, countCreateParticleBuffer_gpu, PropF(@"passiveMultiplier"));
                      }
                      
                      double passiveTime = gcl_stop_timer(passiveTimer);
                      //###################################
                      
                      
                      //############# ADD #############
                      cl_timer addTimer = gcl_start_timer();
                      
                      for(int i=0;i<5;i++){
                          addParticles_kernel(&ndrangeTexAdd, particle_gpu, isDead_gpu, countCreateParticleBuffer_gpu, TEXTURE_RES, frameNum+=10, NUM_PARTICLES_FRAC, countActiveBuffer_gpu);
                      }
                      double addTime = gcl_stop_timer(addTimer);
                      //###################################
                      
                      
                      
                      //############### SUM ###############
                      cl_timer sumTimer = gcl_start_timer();
                      
                      sumParticleForces_kernel(&ndrange, particle_gpu, forceField_gpu,  TEXTURE_RES,forceFieldParticleInfluence);
                      
                      //DEBUG
                      //sumCounter_kernel(&ndrange, particle_gpu, isDead_gpu, counter_gpu, 1024*sizeof(ParticleCounter));
                      
                      double sumTime = gcl_stop_timer(sumTimer);
                      //###################################
                      
                      
                      
                      //####################################
                      forceTimer = gcl_start_timer();
                      if(forceTextureForce){
                          /*cl_ndrange ndrangeForce = {
                           1,                     // The number of dimensions to use.
                           {0, 0, 0},
                           {NUM_PARTICLES_FRAC, 0, 0},
                           {1024}
                           };*/
                          /* if(forceTextureBlur){
                           forceTextureForce_kernel(&ndrange, particle_gpu, pos_gpu, forceCacheBlur_gpu, forceTextureForce*0.01, forceTextureMaxForce, TEXTURE_RES);
                           } else*/ {
                               forceTextureForce_kernel(&ndrange, particle_gpu, forceField_gpu, forceTextureForce*0.01, forceTextureMaxForce, TEXTURE_RES/*, sizeof(cl_int2)*1024*5*/ );
                               
                           }
                      }
                      forceTime += gcl_stop_timer(forceTimer);
                      //####################################
                      
                      
                      
                      
                      
                      //###############
                      cl_timer updateTimer = gcl_start_timer();
                      
                      update_kernel(&ndrange, (Particle*)particle_gpu, isDead_gpu, generalDt* 1.0/ofGetFrameRate(), 1.0-particleDamp, particleMinSpeed, particleFadeInSpeed*0.01 ,particleFadeOutSpeed*0.01, TEXTURE_RES, stickyBuffer_gpu, PropF(@"stickyAmount"), PropF(@"stickyGain"));
                      
                      double updateTime = gcl_stop_timer(updateTimer);
                      //###############
                      
                      
                      
                      
                      
                      
                      
                      
                      
                      //###############
                      cl_timer updateTexTimer = gcl_start_timer();
                      updateTexture_kernel(&ndrangeTex, texture_gpu[textureFlipFlop], texture_gpu[!textureFlipFlop], 1024*sizeof(int), countActiveBuffer_gpu, countInactiveBuffer_gpu, countPassiveBuffer_gpu,  PropF(@"passiveMultiplier"));
                      double updateTexTime = gcl_stop_timer(updateTexTimer);
                      
                      textureFlipFlop = !textureFlipFlop;
                      //###############
                      
                      
                      
                      
                      
                      //      gaussian_blur_kernel(&ndrangeTexNDef, texture_gpu, mask_gpu, texture_blur_gpu, maskSize);
                      
                      
                      if(drawForceTexture){
                          updateForceTexture_kernel(&ndrangeTex, forceTexture_gpu, forceField_gpu);
                      }
                      
                      
                      if(PropF(@"passiveBlur")){
                          gaussianBlurBuffer_kernel(&ndrangeTex, countPassiveBuffer_gpu, mask_gpu, maskSize, PropF(@"passiveBlur"), PropF(@"passiveFade"));
                      }
                      
                      
                      cl_ndrange ndrangeReset = {
                          1,
                          {0, 0, 0},
                          {TEXTURE_RES*TEXTURE_RES},
                          {0}
                      };
                      resetCache_kernel(&ndrangeReset, countInactiveBuffer_gpu, countActiveBuffer_gpu, forceField_gpu,bodyField_gpu[0]);
                      
                      
                      
                      
                      double totalTime = gcl_stop_timer(totalTimer);
                      
                      
                      //--------------
                      
                      
                      
                      
                      dispatch_semaphore_signal(cl_gl_semaphore);
                      
                      
                      //DEBUG
                      //    gcl_memcpy(counter, counter_gpu, sizeof(ParticleCounter));
                      //      NSLog(@"Active: %i inactive: %i dead: %i deadbit: %i",counter->activeParticles, counter->inactiveParticles, counter->deadParticles, counter->deadParticlesBit);
                      
                      if(PropB(@"_debug")){
                          newDataJumper ++;
                      if(!firstLoop && newDataJumper %5 == 0){
                          dispatch_async(dispatch_get_main_queue(), ^{
                              NSDictionary * dict = @{
                              totalIdentifier : @(totalTime),
                              updateIdentifier : @(updateTime),
                              updateTextureIdentifier :@(updateTexTime+updateTime),
                              sumIdentifier : @(sumTime+updateTexTime+updateTime),
                              forceIdentifier : @(forceTime+sumTime+updateTexTime+updateTime),
                              passiveIdentifier : @(forceTime+sumTime+updateTexTime+updateTime+passiveTime),
                              addIdentifier : @(forceTime+sumTime+updateTexTime+updateTime+passiveTime+addTime),
                              activeIdentifier : @(0.1*counter->activeParticles/(float)NUM_PARTICLES_FRAC),
                              inactiveIdentifier : @(0.1*counter->inactiveParticles/(float)NUM_PARTICLES_FRAC),
                              deadIdentifier : @(0.1*counter->deadParticles/(float)NUM_PARTICLES_FRAC)
                              };
                            //  [self newData:dict];
                          });
                          
                      }
                      }
                      
                      
                  });
    
    dispatch_semaphore_wait(cl_gl_semaphore, DISPATCH_TIME_FOREVER);
    
    
    
    
    
    ofEnableAlphaBlending();
    // ofBackground(0.0*255,0.0*255,0.0*255);
    
    
    ofSetColor(255,255,255);
    //Shader
    glUseProgramObjectARB(programObject);
	
	//glUniform1fvARB(locations[kUniformOffset], 1, &offset);
	glUniform3fARB(shaderLocations[0], PropF(@"lightX"), PropF(@"lightY"), PropF(@"lightZ"));
    glUniform1fARB(shaderLocations[1], PropF(@"shaderGain"));
    glUniform1fARB(shaderLocations[2], PropF(@"shaderDiffuse"));
    
    glEnable( GL_TEXTURE_2D );
    glBindTexture( GL_TEXTURE_2D, texture[textureFlipFlop] );
    
    
    ApplySurface(@"Floor");
    
    glBegin(GL_QUADS);
    
    glTexCoord2d(0.0,0.0); glVertex2d(0.0,0.0);
    glTexCoord2d(1.0,0.0); glVertex2d(1.0,0.0);
    glTexCoord2d(1.0,1.0); glVertex2d(1.0,1.0);
    glTexCoord2d(0.0,1.0); glVertex2d(0.0,1.0);
    glEnd();
    
    PopSurface();
    
    /*
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
     
     */
	
    glDisable(GL_TEXTURE_2D);
    
    // Unbind the shader
	glUseProgramObjectARB(NULL);
    
    
    if(PropB(@"drawTexture")){
        ofSetColor(255, 255, 255);
        
        glEnable( GL_TEXTURE_2D );
        glBindTexture( GL_TEXTURE_2D, texture[textureFlipFlop] );
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
    
    
    ApplySurface(@"Floor");
    
    
    //   vector<ofVec2f> trackers = [GetPlugin(OSCControl) getTrackerCoordinates];
    ofSetColor(100, 100, 100);
    for(int i=0;i<trackers.size();i++){
        ofCircle(trackers[i].y, 1-trackers[i].x, 0.01);
    }
    
    firstLoop = NO;
    
    PopSurface();
    
    
}

-(void)awakeFromNib{
    //NSDate *refDate       = [NSDate dateWithNaturalLanguageString:@"12:00 Oct 29, 2009"];
    //  NSTimeInterval oneDay = 24 * 60 * 60;
    
    
    // Create graph from theme
    graph = [(CPTXYGraph *)[CPTXYGraph alloc] initWithFrame:CGRectZero];
    CPTTheme *theme = [CPTTheme themeNamed:nil];
    [graph applyTheme:theme];
    graphView.hostedGraph = graph;
    
    graph.plotAreaFrame.paddingTop    = 15.0;
    graph.plotAreaFrame.paddingRight  = 15.0;
    graph.plotAreaFrame.paddingBottom = 55.0;
    graph.plotAreaFrame.paddingLeft   = 55.0;
    
    
    // Title
    CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color         = [CPTColor blackColor];
    textStyle.fontSize      = 14.0f;
    textStyle.fontName      = @"Helvetica";
    graph.title             = @"Profiling";
    graph.titleTextStyle    = textStyle;
    graph.titleDisplacement = CGPointMake(0.0f, -0.0f);
    
    
    // Setup scatter plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0) length:CPTDecimalFromFloat(5.0f)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0) length:CPTDecimalFromFloat(1.1)];
    
    
    // Axes
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x          = axisSet.xAxis;
    x.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    x.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
    //    x.majorIntervalLength         = CPTDecimalFromFloat(1);
    x.minorTicksPerInterval       = 9;
    //    x.labelFormatter            = timeFormatter;
    
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    y.orthogonalCoordinateDecimal = CPTDecimalFromFloat(+.0);
    y.minorTicksPerInterval       = 9;
    
    
    
    // Create a plot that uses the data source method
    for(int i=0;i<10;i++){
        CPTScatterPlot *dataSourceLinePlot = [[[CPTScatterPlot alloc] init] autorelease];
        CPTMutableLineStyle *lineStyle = [[dataSourceLinePlot.dataLineStyle mutableCopy] autorelease];
        lineStyle.lineWidth              = 1.0;
        lineStyle.lineColor              = [CPTColor blackColor];
        
        switch (i) {
            case 0:
                dataSourceLinePlot.identifier = totalIdentifier;
                break;
            case 1:
                dataSourceLinePlot.identifier = updateIdentifier;
                lineStyle.lineColor              = [CPTColor redColor];
                
                break;
            case 2:
                dataSourceLinePlot.identifier = updateTextureIdentifier;
                lineStyle.lineColor              = [CPTColor greenColor];
                break;
                
            case 3:
                dataSourceLinePlot.identifier = sumIdentifier;
                lineStyle.lineColor              = [CPTColor blueColor];
                break;
                
            case 4:
                dataSourceLinePlot.identifier = forceIdentifier;
                lineStyle.lineColor              = [CPTColor orangeColor];
                break;
                
            case 5:
                dataSourceLinePlot.identifier = activeIdentifier;
                lineStyle.lineColor              = [CPTColor colorWithComponentRed:0.0 green:0.5 blue:0.0 alpha:1.0] ;
                lineStyle.dashPattern = [NSArray arrayWithObjects:
                                         [NSNumber numberWithFloat:5.0f],
                                         [NSNumber numberWithFloat:5.0f],
                                         nil];
                
                break;
                
            case 6:
                dataSourceLinePlot.identifier = inactiveIdentifier;
                lineStyle.lineColor              = [[CPTColor orangeColor] colorWithAlphaComponent:0.8];
                lineStyle.dashPattern = [NSArray arrayWithObjects:
                                         [NSNumber numberWithFloat:5.0f],
                                         [NSNumber numberWithFloat:5.0f],
                                         nil];
                
                break;
                
            case 7:
                dataSourceLinePlot.identifier = deadIdentifier;
                lineStyle.lineColor              = [[CPTColor redColor] colorWithAlphaComponent:0.5];
                lineStyle.dashPattern = [NSArray arrayWithObjects:
                                         [NSNumber numberWithFloat:5.0f],
                                         [NSNumber numberWithFloat:5.0f],
                                         nil];
                break;
                
            case 8:
                dataSourceLinePlot.identifier = addIdentifier;
                lineStyle.lineColor              = [CPTColor purpleColor];
                break;
            case 9:
                dataSourceLinePlot.identifier = passiveIdentifier;
                lineStyle.lineColor              = [CPTColor blackColor];
                break;
                
                
            default:
                break;
        }
        dataSourceLinePlot.cachePrecision = CPTPlotCachePrecisionDouble;
        
        // Add line style
        dataSourceLinePlot.dataLineStyle = lineStyle;
        
        dataSourceLinePlot.dataSource = self;
        
        // Add plot
        [graph addPlot:dataSourceLinePlot];
        graph.defaultPlotSpace.delegate = self;
    }
    
    // Store area fill for use later
    /*    CPTColor *transparentGreen = [[CPTColor greenColor] colorWithAlphaComponent:0.2];
     areaFill = [[CPTFill alloc] initWithColor:(id)transparentGreen];
     */
    // Add some data
    
    self.plotData = [NSMutableArray array];
    currentIndex = 0;
    
    // Add legend
    graph.legend                 = [CPTLegend legendWithGraph:graph];
    graph.legend.textStyle       = x.titleTextStyle;
    // graph.legend.fill            = [CPTFill fillWithColor:[CPTColor darkGrayColor]];
    graph.legend.borderLineStyle = x.axisLineStyle;
    graph.legend.cornerRadius    = 5.0;
    //    graph.legend.swatchSize      = CGSizeMake(25.0, 25.0);
    graph.legendAnchor           = CPTRectAnchorTopLeft;
    graph.legendDisplacement     = CGPointMake(0.0, 0.0);
    
    /* dataTimer = [[NSTimer timerWithTimeInterval:1.0 / 10.0
     target:self
     selector:@selector(newData)
     userInfo:nil
     repeats:YES] retain];
     [[NSRunLoop mainRunLoop] addTimer:dataTimer forMode:NSDefaultRunLoopMode];
     
     */
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


#pragma mark -
#pragma mark Plot Data Source Methods


-(void)newData:(NSDictionary*)arr
{
    int kMaxDataPoints = 300;
    CPTGraph *theGraph = graph;
    
    if ( self.plotData.count >= kMaxDataPoints ) {
        [self.plotData removeObjectAtIndex:0];
        for(CPTPlot *thePlot in [theGraph allPlots]){
            
            [thePlot deleteDataInIndexRange:NSMakeRange(0, 1)];
        }
    }
    
    
    [self.plotData addObject:arr];
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
    NSUInteger location       = (currentIndex >= kMaxDataPoints ? currentIndex - kMaxDataPoints + 1 : 0);
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(location)
                                                    length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 1)];
    
    //    plotSpace.yRange.locationDouble = 1.0;
    
    /* [plotSpace scaleToFitPlots:[theGraph allPlots]];
     CPTMutablePlotRange *yRange = [[plotSpace.yRange mutableCopy] autorelease];
     [yRange expandRangeByFactor:CPTDecimalFromDouble(1.3)];
     plotSpace.yRange = yRange;
     */
    
    currentIndex++;
    
    //  if(self.plotData.count  > 1){
    for(CPTPlot *thePlot in [theGraph allPlots]){
        //   NSLog(@"Insert at %i   %@",self.plotData.count - 1,arr );
        [thePlot insertDataAtIndex:self.plotData.count - 1 numberOfRecords:1];
    }
    // }
}

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return self.plotData.count;
}
/*
 -(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
 {
 NSDecimalNumber *num = [[plotData objectAtIndex:index] objectForKey:[NSNumber numberWithInt:fieldEnum]];
 
 return num;
 }*/
-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = nil;
    
    switch ( fieldEnum ) {
        case CPTScatterPlotFieldX:
            num = [NSNumber numberWithUnsignedInteger:index + currentIndex - self.plotData.count];
            break;
            
        case CPTScatterPlotFieldY:
            num = @(10.0*[[[self.plotData objectAtIndex:index] valueForKey:(NSString*)plot.identifier] floatValue]);
            break;
            
        default:
            break;
    }
    
    return num;
}

/*-(BOOL)plotSpace:(CPTPlotSpace *)space shouldHandlePointingDeviceUpEvent:(id)event atPoint:(CGPoint)point
 {
 CPTRangePlot *rangePlot = (CPTRangePlot *)[graph plotWithIdentifier:@"Date Plot"];
 
 rangePlot.areaFill     = (rangePlot.areaFill ? nil : areaFill);
 rangePlot.barLineStyle = (rangePlot.barLineStyle ? nil : barLineStyle);
 
 return NO;
 }*/
@end
