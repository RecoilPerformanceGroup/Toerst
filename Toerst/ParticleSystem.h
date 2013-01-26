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
    unsigned int          * isDead;
    
    
    dispatch_queue_t queue;
    dispatch_semaphore_t cl_gl_semaphore;
    
    
    cl_uint          *isDead_gpu;
    Particle        *particle_gpu;
    cl_image        texture_gpu[2];
    cl_image      texture_blur_gpu;
    cl_image        forceTexture_gpu;
    //cl_image      forceTexture_blur_gpu;
    cl_uint          *countActiveBuffer_gpu;
    cl_uint          *countInactiveBuffer_gpu;
    cl_uint          *countPassiveBuffer_gpu;
    cl_uint          *countWakeUpBuffer_gpu;
    cl_uint          *countCreateParticleBuffer_gpu;

    cl_int          *bodyField_gpu[2];
    cl_int          *bodyBlob_gpu;
    cl_int          *forceField_gpu;
    cl_int          *forceCacheBlur_gpu;
    cl_float        *mask_gpu;
    ParticleCounter *counter_gpu;
    
    
    int * bodyBlobData;
    
    BOOL            firstLoop;
    
    float           _clTime;
    
    int             maskSize;
    
    bool textureFlipFlop;
    

    IBOutlet CPTGraphHostingView *graphView;
    CPTXYGraph *graph;
    CPTFill *areaFill;
    CPTLineStyle *barLineStyle;
    NSUInteger currentIndex;
    NSTimer * dataTimer;

    NSMutableArray *_plotData;
    
    int frameNum;
    bool passiveWasActive;
}

@property (readwrite) float clTime;
@property     NSMutableArray *plotData;

@end
