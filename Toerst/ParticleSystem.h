//
//  ParticleSystem.h
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//

#import <ofxCocoaPlugins/ofxCocoaPlugins.h>

#import <OpenCL/OpenCL.h>
#import "kernel.cl.h"

@interface ParticleSystem : ofPlugin{
    GLuint				vbo;
    GLuint              texture;
    GLuint              forceTexture;

    
    dispatch_queue_t queue;
    dispatch_semaphore_t cl_gl_semaphore;
    
    
    ParticleVBO * pos_gpu;
    Particle* particle_gpu;
    cl_image texture_gpu;
    cl_image forceTexture_gpu;
    cl_int * countCache_gpu;
    cl_int * forceCache_gpu;
    
    BOOL firstLoop;
    
    float _clTime;
}

@property (readwrite) float clTime;

@end
