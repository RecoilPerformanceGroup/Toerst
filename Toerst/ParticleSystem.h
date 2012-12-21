//
//  ParticleSystem.h
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//

#import <ofxCocoaPlugins/ofxCocoaPlugins.h>
#import <CorePlot/CorePlot.h>

#import <OpenCL/OpenCL.h>
#import "kernel.cl.h"
#import "Shader.h"



@interface ParticleSystem : ofPlugin<CPTPlotDataSource, CPTPlotSpaceDelegate>{
    GLuint				vbo;
    GLuint              texture[2];
    GLuint              forceTexture;
    GLuint              texture_blur;
  //  GLuint              forceTexture_blur;

    Shader          *diffuse;
    GLhandleARB		programObject;				// the program object
    GLint           shaderLocations[3];
    
    ParticleCounter          *counter;
    
    
    dispatch_queue_t queue;
    dispatch_semaphore_t cl_gl_semaphore;
    
    
    ParticleVBO     *pos_gpu;
    Particle        *particle_gpu;
    cl_image        texture_gpu[2];
    cl_image      texture_blur_gpu;
    cl_image        forceTexture_gpu;
    //cl_image      forceTexture_blur_gpu;
    cl_int          *countActiveBuffer_gpu;
    cl_int          *countInactiveBuffer_gpu;
    cl_int          *countPassiveBuffer_gpu;
    cl_int          *countWakeUpBuffer_gpu;
    
    cl_int          *forceField_gpu;
    cl_int          *forceCacheBlur_gpu;
    cl_float        *mask_gpu;
    ParticleCounter *counter_gpu;
    
    BOOL            firstLoop;
    
    float           _clTime;
    
    int             maskSize;
    
    bool textureFlipFlop;
    

    IBOutlet CPTGraphHostingView *graphView;
    CPTXYGraph *graph;
    NSMutableArray *plotData;
    CPTFill *areaFill;
    CPTLineStyle *barLineStyle;
    NSUInteger currentIndex;
    NSTimer * dataTimer;

}

@property (readwrite) float clTime;

@end
