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
#define NUM_PARTICLES (1024*1500)
#define NUM_PARTICLES_FRAC  MAX(1024, (NUM_PARTICLES * (  floor(PropF(@"generalUpdateFraction") * 1024)/1024.0)))



static NSString *totalIdentifier = @"Total";
static NSString *updateIdentifier = @"Update";
static NSString *updateTextureIdentifier = @"Update Texture";
static NSString *sumIdentifier = @"Sum";
static NSString *forceIdentifier = @"Forces";
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
    [[self addPropF:@"generalUpdateFraction"] setMinValue:0.1 maxValue:1.0];
    [Prop(@"generalUpdateFraction") setDefaultValue:@(1)];
    
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
    
    [[self addPropF:@"lightX"] setMinValue:-1 maxValue:1];
    [[self addPropF:@"lightY"] setMinValue:-1 maxValue:1];
    [[self addPropF:@"lightZ"] setMinValue:-1 maxValue:1];
    
    
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
    graph.titleDisplacement = CGPointMake(0.0f, -20.0f);
    
    
    // Setup scatter plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0) length:CPTDecimalFromFloat(5.0f)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0) length:CPTDecimalFromFloat(1.0)];
    
    
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
    for(int i=0;i<5;i++){
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
    
    plotData = [NSMutableArray array];
    currentIndex = 0;
    
    // Add legend
    graph.legend                 = [CPTLegend legendWithGraph:graph];
    graph.legend.textStyle       = x.titleTextStyle;
    // graph.legend.fill            = [CPTFill fillWithColor:[CPTColor darkGrayColor]];
    graph.legend.borderLineStyle = x.axisLineStyle;
    graph.legend.cornerRadius    = 5.0;
    //    graph.legend.swatchSize      = CGSizeMake(25.0, 25.0);
    graph.legendAnchor           = CPTRectAnchorTopRight;
    graph.legendDisplacement     = CGPointMake(0.0, 0.0);
    
    /* dataTimer = [[NSTimer timerWithTimeInterval:1.0 / 10.0
     target:self
     selector:@selector(newData)
     userInfo:nil
     repeats:YES] retain];
     [[NSRunLoop mainRunLoop] addTimer:dataTimer forMode:NSDefaultRunLoopMode];
     
     */
}

-(void)setup{
    glewInit();
    
    ParticleVBO	*			particlesVboData;
    Particle *			particles;
    
    particlesVboData = (ParticleVBO*) malloc(NUM_PARTICLES* sizeof(ParticleVBO));
    particles = (Particle*) malloc(NUM_PARTICLES* sizeof(Particle));
    
    cout<<"Particle size: "<<sizeof(Particle)<<endl;
    
    for(int i=0; i<NUM_PARTICLES; i++) {
		Particle &p = particles[i];
		p.vel.s[0] = 0;//ofRandom(-1,1);
		p.vel.s[1] = 0;//ofRandom(-1,1);
		p.mass = ofRandom(0.5, 1);
        p.pos.s[0] = ofRandom(1);
        p.pos.s[1] = ofRandom(1);
        p.dead = NO;
        
        //	particlesPos[i] = ofVec2f(ofRandom(1), ofRandom(1));
        /*        particlesVboData[i].pos.s[0] = -1;
         particlesVboData[i].pos.s[1] = -1;*/
        particlesVboData[i].pos.s[0] = p.pos.s[0];
        particlesVboData[i].pos.s[1] = p.pos.s[1];
        particlesVboData[i].color.s[0] = 1;
        particlesVboData[i].color.s[1] = 1;
        particlesVboData[i].color.s[2] = 1;
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
    
    pos_gpu = (ParticleVBO*)gcl_gl_create_ptr_from_buffer(vbo);
    
    texture_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, texture);
    forceTexture_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, forceTexture);
    texture_blur_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, texture_blur);
    //    forceTexture_blur_gpu = gcl_gl_create_image_from_texture(GL_TEXTURE_2D, 0, forceTexture_blur);
    
    particle_gpu  = (Particle*)gcl_malloc(sizeof(Particle) * NUM_PARTICLES, particles,
                                          CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR);
    
    
    countCache_gpu = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES,  nil, CL_MEM_READ_WRITE );
    forceCache_gpu = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES*2,  nil, CL_MEM_READ_WRITE );
    forceCacheBlur_gpu = (cl_int*) gcl_malloc(sizeof(cl_int)*TEXTURE_RES*TEXTURE_RES*2,  nil, CL_MEM_READ_WRITE );
    
    float * mask =createBlurMask(2.0f, &maskSize);
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
    
    
    diffuse = [[Shader alloc] initWithShadersInAppBundle:@"diffuse"];
    if(diffuse){
        programObject = [diffuse programObject];
        
        glUseProgramObjectARB(programObject);
        shaderLocations[0] = [diffuse getUniformLocation:"light"];
        
        glUseProgramObjectARB(NULL);
        
    }
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
    dispatch_sync(queue,
                   ^{
                       cl_timer totalTimer = gcl_start_timer();
                       
                       // NSLog(@"%f %f",NUM_PARTICLES_FRAC, PropF(@"generalUpdateFraction"));
                       
                       cl_ndrange ndrange = {
                           1,                     // The number of dimensions to use.
                           {0, 0, 0},
                           {NUM_PARTICLES_FRAC, 0, 0},
                           {0}
                       };
                       cl_ndrange ndrangeGaus = {
                           2,
                           {0, 0, 0},
                           {TEXTURE_RES, TEXTURE_RES},
                           {0}
                       };
                       
                       int wd = 32;
                       cl_ndrange ndrangeSum = {
                           2,
                           {0, 0, 0},
                           {TEXTURE_RES, TEXTURE_RES},
                           {wd,wd}
                       };
                       
                       cl_timer sumTimer = gcl_start_timer();
                       sumParticles_kernel(&ndrange, particle_gpu,countCache_gpu, forceCache_gpu,  TEXTURE_RES);
                       //sumParticles2_kernel(&ndrangeSum, particle_gpu, pos_gpu, countCache_gpu, forceCache_gpu,NUM_PARTICLES_FRAC, wd*wd*sizeof(int));
                       double sumTime = gcl_stop_timer(sumTimer);
                       


                       if(forceTextureBlur){
                           gaussianBlurSum_kernel(&ndrangeGaus,  forceCache_gpu, forceCacheBlur_gpu, TEXTURE_RES, mask_gpu, maskSize);
                       }
                       //------------------
                       // Forces
                       //------------------
                       cl_timer forceTimer = gcl_start_timer();

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
                               mouseForce_kernel(&ndrange, (Particle*)particle_gpu, mousePos , mouseForce*0.1, mouseRadius*0.3);
                           }
                           
                           float n = 10.0f;
                           if(mouseAdd){
                               cl_ndrange ndrangeMouse = {
                                   1,                     // The number of dimensions to use.
                                   {0, 0, 0},
                                   {n, 0, 0},
                                   {0}
                               };
                               
                               mouseAdd_kernel(&ndrangeMouse, particle_gpu, pos_gpu, mousePos, mouseRadius, mouseAdd, NUM_PARTICLES_FRAC);
                           }
                       }
                       double forceTime = gcl_stop_timer(forceTimer);

                       
                       cl_timer updateTimer = gcl_start_timer();
                       update_kernel(&ndrange, (Particle*)particle_gpu, pos_gpu , generalDt* 1.0/ofGetFrameRate(), 1.0-particleDamp, particleMinSpeed, particleFadeInSpeed*0.01 ,particleFadeOutSpeed*0.01);
                       double updateTime = gcl_stop_timer(updateTimer);
                       
                       
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
                       
                       
                       
                       //if(textureForce){
                       //  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
                       cl_timer updateTexTimer = gcl_start_timer();
                       updateTexture_kernel(&ndrangeTex, texture_blur_gpu, pos_gpu, NUM_PARTICLES_FRAC, 1024*sizeof(int), countCache_gpu );
                       double updateTexTime = gcl_stop_timer(updateTexTimer);
                       
                       // gaussian_blur_kernel(&ndrangeTexNDef, texture_gpu, mask_gpu, texture_blur_gpu, maskSize);
                       
                       // }
                       
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
                       
                       
                       double totalTime = gcl_stop_timer(totalTimer);
                       
                       dispatch_semaphore_signal(cl_gl_semaphore);
                       
                       if(!firstLoop){
                           dispatch_async(dispatch_get_main_queue(), ^{
                               //   self.clTime =  t;//1000.0*[time timeIntervalSinceNow];
                               //                           cout<<t<<endl;
                               NSDictionary * dict = @{
                               totalIdentifier : @(totalTime),
                               updateIdentifier : @(updateTime),
                               updateTextureIdentifier :@(updateTexTime),
                               sumIdentifier : @(sumTime),
                               forceIdentifier : @(forceTime)
                               };
                               [self newData:dict];
                               //                           cout<<self.clTime<<endl;
                               
                           });
                       }
                       
                   });
    // Queue CL kernel to dispatch queue.
    
   // if(!firstLoop)
    //dispatch_semaphore_wait(cl_gl_semaphore, DISPATCH_TIME_FOREVER);
    
    
    ofEnableAlphaBlending();
    ofBackground(0.0*255,0.0*255,0.0*255);
    
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
    //NSDate * time = [NSDate date];
    
    
   
    ofSetColor(255,255,255);
    //Shader
    //glUseProgramObjectARB(programObject);
	
	//glUniform1fvARB(locations[kUniformOffset], 1, &offset);
	glUniform3fARB(shaderLocations[0], PropF(@"lightX"), PropF(@"lightY"), PropF(@"lightZ"));
    
    glEnable( GL_TEXTURE_2D );
    glBindTexture( GL_TEXTURE_2D, texture_blur );
    
    glBegin(GL_QUADS);
    
    glTexCoord2d(0.0,0.0); glVertex2d(0.0,0.0);
    glTexCoord2d(1.0,0.0); glVertex2d(1.0,0.0);
    glTexCoord2d(1.0,1.0); glVertex2d(1.0,1.0);
    glTexCoord2d(0.0,1.0); glVertex2d(0.0,1.0);
    glEnd();
    
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
    
    
    
    
    //   vector<ofVec2f> trackers = [GetPlugin(OSCControl) getTrackerCoordinates];
    ofSetColor(100, 100, 100);
    for(int i=0;i<trackers.size();i++){
        ofCircle(trackers[i].y, 1-trackers[i].x, 0.01);
    }
    
    firstLoop = NO;
    
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
    
    if ( plotData.count >= kMaxDataPoints ) {
        [plotData removeObjectAtIndex:0];
        for(CPTPlot *thePlot in [theGraph allPlots]){
            
            [thePlot deleteDataInIndexRange:NSMakeRange(0, 1)];
        }
    }
    
    
    [plotData addObject:arr];
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
    NSUInteger location       = (currentIndex >= kMaxDataPoints ? currentIndex - kMaxDataPoints + 1 : 0);
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(location)
                                                    length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 1)];
    
    
    
    /* [plotSpace scaleToFitPlots:[theGraph allPlots]];
     CPTMutablePlotRange *yRange = [[plotSpace.yRange mutableCopy] autorelease];
     [yRange expandRangeByFactor:CPTDecimalFromDouble(1.3)];
     plotSpace.yRange = yRange;
     */
    
    currentIndex++;
    
    for(CPTPlot *thePlot in [theGraph allPlots]){
        [thePlot insertDataAtIndex:plotData.count - 1 numberOfRecords:1];
    }
}

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return plotData.count;
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
            num = [NSNumber numberWithUnsignedInteger:index + currentIndex - plotData.count];
            break;
            
        case CPTScatterPlotFieldY:
            num = @(10.0*[[[plotData objectAtIndex:index] valueForKey:(NSString*)plot.identifier] floatValue]);
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
