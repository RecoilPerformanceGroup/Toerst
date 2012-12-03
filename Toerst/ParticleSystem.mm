//
//  ParticleSystem.m
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//

#import "ParticleSystem.h"

//#define NUM_PARTICLES (1024*128)
#define NUM_PARTICLES (1024)
/*

typedef struct{
	ofVec2f vel;
	float mass;
	float dummy;		// need this to make sure the float2 vel is aligned to a 16 byte boundary
} Particle;*/

@implementation ParticleSystem

-(void)initPlugin{
    firstLoop = YES;
  /*  int i;
    char name[128];
    
    // First, try to obtain a dispatch queue that can send work to the
    // GPU in our system.                                                [2]
    dispatch_queue_t queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_GPU,
                                                       NULL);
    
    // In the event that our system does NOT have an OpenCL-compatible GPU,
    // we can use the OpenCL CPU compute device instead.
    if (queue == NULL) {
        queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_CPU, NULL);
    }
    
    // This is not required, but let's print out the name of the device
    // we are using to do work.  We could use the same function,
    // clGetDeviceInfo, to obtain all manner of information about the device.
    cl_device_id gpu = gcl_get_device_id_with_dispatch_queue(queue);
    clGetDeviceInfo(gpu, CL_DEVICE_NAME, 128, name, NULL);
    fprintf(stdout, "Created a dispatch queue using the %s\n", name);
    
    // Now we gin up some test data.  This is typically the case: you have some
    // data in your application that you want to process with OpenCL.  This
    // test_in buffer represents such data.  Normally, this would come from
    // some REAL source, like a camera, a sensor, or some compiled collection
    // of statistics -- it just depends on the problem you want to solve.
    float* test_in = (float*)malloc(sizeof(cl_float) * NUM_VALUES);
    for (i = 0; i < NUM_VALUES; i++) {
        test_in[i] = (cl_float)i;
    }
    
    // Once the computation using CL is done, we'll want to read the results
    // back into our application's memory space.  Allocate some space for that.
    float* test_out = (float*)malloc(sizeof(cl_float) * NUM_VALUES);
    
    // Our test kernel takes two parameters: an input float array and an
    // output float array.  We can't send the application's buffers above, since
    // our CL device operates on its own memory space.  Therefore, we allocate
    // OpenCL memory for doing the work.  Notice that for the input array,
    // we specify CL_MEM_COPY_HOST_PTR and provide the fake input data we
    // created above.  This tells OpenCL to copy over our data into its memory
    // space before it executes the kernel.                                   [3]
    void* mem_in  = gcl_malloc(sizeof(cl_float) * NUM_VALUES, test_in,
                               CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR);
    
    // The output array is not initalized; we're going to fill it up when
    // we execute our kernel.                                                 [4]
    void* mem_out = gcl_malloc(sizeof(cl_float) * NUM_VALUES, NULL,
                               CL_MEM_WRITE_ONLY);
    
    // Dispatch your kernel block using one of the dispatch_ commands and the
    // queue we created above.                                                [5]
    
    dispatch_sync(queue, ^{
        
        // Though we COULD pass NULL as the workgroup size, which would tell
        // OpenCL to pick the one it thinks is best, we can also ask
        // OpenCL for the suggested size, and pass it ourselves.              [6]
        size_t wgs;
        gcl_get_kernel_block_workgroup_info(square_kernel,
                                            CL_KERNEL_WORK_GROUP_SIZE,
                                            sizeof(wgs), &wgs, NULL);
        
        // The N-Dimensional Range over which we'd like to execute our
        // kernel.  In our example case, we're operating on a 1D buffer, so
        // it makes sense that our range is 1D.
        cl_ndrange range = {
            1,                     // The number of dimensions to use.
            
            {0, 0, 0},             // The offset in each dimension.  We want to
            // process ALL of our data, so this is 0 for
            // our test case.                          [7]
            
            {NUM_VALUES, 0, 0},    // The global range -- this is how many items
            // IN TOTAL in each dimension you want to
            // process.
            
            {wgs, 0, 0} // The local size of each workgroup.  This
            // determines the number of workitems per
            // workgroup.  It indirectly affects the
            // number of workgroups, since the global
            // size / local size yields the number of
            // workgroups.  So in our test case, we will
            // have NUM_VALUE / wgs workgroups.
        };
        // Calling the kernel is easy; you simply call it like a function,
        // passing the ndrange as the first parameter, followed by the expected
        // kernel parameters.  Note that we case the 'void*' here to the
        // expected OpenCL types.  Remember -- if you use 'float' in your
        // kernel, that's a 'cl_float' from the application's perspective.   [8]
        
        square_kernel(&range,(cl_float*)mem_in, (cl_float*)mem_out);
        
        // Getting data out of the device's memory space is also easy; we
        // use gcl_memcpy.  In this case, we take the output computed by the
        // kernel and copy it over to our application's memory space.        [9]
        
        gcl_memcpy(test_out, mem_out, sizeof(cl_float) * NUM_VALUES);
        
    });
    
    
    // Now we can check to make sure our kernel really did what we asked
    // it to:
    
  
    // Don't forget to free up the CL device's memory when you're done.      [10]
    gcl_free(mem_in);
    gcl_free(mem_out);
    
    // And the same goes for system memory, as usual.
    free(test_in);
    free(test_out);
    
    // Finally, release your queue just as you would any GCD queue.          [11]
    dispatch_release(queue);*/
}

-(void)setup{
    glewInit();
    
    ofVec2f	*			particlesPos;
    Particle *			particles;
    
    particlesPos = (ofVec2f*) malloc(NUM_PARTICLES* sizeof(ofVec2f));
    particles = (Particle*) malloc(NUM_PARTICLES* sizeof(Particle));
    
    for(int i=0; i<NUM_PARTICLES; i++) {
		Particle &p = particles[i];
		p.vel.s[0] = ofRandom(-1,1);
		p.vel.s[1] = ofRandom(-1,1);
		p.mass = ofRandom(0.5, 1);
		particlesPos[i] = ofVec2f(ofRandom(1), ofRandom(1));
	}
    
    
    cout<<"Size: "<<sizeof(Particle)<<endl;
    


    
    //VBO
    /*glGenBuffersARB(1, &vbo);
	glBindBufferARB(GL_ARRAY_BUFFER_ARB, vbo);
	glBufferDataARB(GL_ARRAY_BUFFER_ARB, sizeof(ofVec2f) * NUM_PARTICLES, particlesPos, GL_DYNAMIC_COPY_ARB);
	glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
    */
    
    glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(ofVec2f) * NUM_PARTICLES, particlesPos, GL_DYNAMIC_COPY);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
  
  
    
    //Shared context
    CGLContextObj cgl_context = CGLGetCurrentContext();
    CGLShareGroupObj sharegroup = CGLGetShareGroup(cgl_context);
    gcl_gl_set_sharegroup(sharegroup);
    
    // Create a CL dispatch queue.
    queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_GPU, NULL);
    // Create a dispatch semaphore used for CL / GL sharing.
    cl_gl_semaphore = dispatch_semaphore_create(0);
    
    pos_gpu = gcl_gl_create_ptr_from_buffer(vbo);
    
    
    particle_gpu  = gcl_malloc(sizeof(Particle) * NUM_PARTICLES, particles,
          CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR);
    
    dispatch_async(queue,
                   ^{
                       gcl_memcpy(pos_gpu, (ofVec2f*)particlesPos,
                                sizeof(ofVec2f)*NUM_PARTICLES);
                   });
    
    
}

int curr_read_index, curr_write_index;

-(void)update:(NSDictionary *)drawingInformation{
    dispatch_async(queue,
                   ^{
                       size_t wgs;
                       gcl_get_kernel_block_workgroup_info(update_kernel,
                                                           CL_KERNEL_WORK_GROUP_SIZE,
                                                           sizeof(wgs), &wgs, NULL);
                       
                       cl_ndrange ndrange = {
                           1,                     // The number of dimensions to use.
                           
                           {0, 0, 0},             // The offset in each dimension.  We want to
                           // process ALL of our data, so this is 0 for
                           // our test case.                          [7]
                           
                           {NUM_PARTICLES, 0, 0},    // The global range -- this is how many items
                           // IN TOTAL in each dimension you want to
                           // process.
                           
                           {wgs, 0, 0} // The local size of each workgroup.  This
                           // determines the number of workitems per
                           // workgroup.  It indirectly affects the
                           // number of workgroups, since the global
                           // size / local size yields the number of
                           // workgroups.  So in our test case, we will
                           // have NUM_VALUE / wgs workgroups.
                       };
                       
                       
                       
                       
                       // Queue CL kernel to dispatch queue.
                       update_kernel(&ndrange, (Particle*)particle_gpu, (cl_float2*)pos_gpu , 0.1* 1.0/ofGetFrameRate());
                       // Signal the dispatch semaphore to indicate that
                       // GL can now use resources.
                       dispatch_semaphore_signal(cl_gl_semaphore);
                   });

}

-(void)draw:(NSDictionary *)drawingInformation{
    // Queue CL kernel to dispatch queue.
    if(!firstLoop)
        dispatch_semaphore_wait(cl_gl_semaphore, DISPATCH_TIME_FOREVER);
    
    
    ofSetColor(255, 255, 255);
    glBindBufferARB(GL_ARRAY_BUFFER_ARB, vbo);
    
    glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(2, GL_FLOAT, 0, 0);
	glDrawArrays(GL_POINTS, 0, NUM_PARTICLES);
	glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);

    firstLoop = NO;
    
   
    vector<ofVec2f> trackers = [GetPlugin(OSCControl) getTrackerCoordinates];
    ofSetColor(100, 100, 100);
    for(int i=0;i<trackers.size();i++){
        ofCircle(trackers[i].x, trackers[i].y, 0.01);
    }
    
}

@end
