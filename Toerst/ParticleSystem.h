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
    
    dispatch_queue_t queue;
    dispatch_semaphore_t cl_gl_semaphore;
    
    
    void * pos_gpu;
    void * particle_gpu;
    
    BOOL firstLoop;
    
    float _clTime;
}

@property (readwrite) float clTime;

@end
