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
#import "Shader.h"

@interface ParticleSystem : ofPlugin{
    GLuint				vbo;
    GLuint              texture;
    GLuint              forceTexture;
    GLuint              texture_blur;
  //  GLuint              forceTexture_blur;

    Shader          *diffuse;
    GLhandleARB		programObject;				// the program object
    GLint           shaderLocations[1];
    
    dispatch_queue_t queue;
    dispatch_semaphore_t cl_gl_semaphore;
    
    
    ParticleVBO     *pos_gpu;
    Particle        *particle_gpu;
    cl_image        texture_gpu;
    cl_image      texture_blur_gpu;
    cl_image        forceTexture_gpu;
    //cl_image      forceTexture_blur_gpu;
    cl_int          *countCache_gpu;
    cl_int          *forceCache_gpu;
    cl_int          *forceCacheBlur_gpu;
    cl_float        *mask_gpu;
    
    BOOL            firstLoop;
    
    float           _clTime;
    
    int             maskSize;
    


}

@property (readwrite) float clTime;

@end
