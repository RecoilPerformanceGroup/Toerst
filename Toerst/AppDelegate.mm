//
//  AppDelegate.m
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//

#import "AppDelegate.h"

#import "ParticleSystem.h"
#import "ParameterRecorder.h"
#import "NanoKontrol.h"
#import "DustVideoPlayer.h"
#import "DmxOutput.h"

//#import
@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    ocp = [[ofxCocoaPlugins alloc] initWithAppDelegate:self];
//       [ocp setNumberOutputviews:2];
    
    [ocp addHeader:@"Setup"];
    
    [ocp addPlugin:[[Midi alloc] init]];
    [ocp addPlugin:[[Keystoner alloc] initWithSurfaces:[NSArray arrayWithObjects:@"Floor", nil]] midiChannel:2 ];
    [ocp addPlugin:[[OSCControl alloc] init]];
    [ocp addPlugin:[[Cameras alloc]initWithNumberCameras:1]];
    [ocp addPlugin:[[CameraCalibration alloc] init]];
    [ocp addPlugin:[[BlobTracker2d alloc] init] midiChannel:11];
    [ocp addPlugin:[[ParticleSystem alloc] init] midiChannel:10];
    [ocp addPlugin:[[Tracker alloc] init]];
    [ocp addPlugin:[[ParameterRecorder alloc] init] midiChannel:12];
    [ocp addPlugin:[[NanoKontrol alloc] init]];
    [ocp addPlugin:[[DmxOutput alloc] init]];
//    [ocp addPlugin:[[DustVideoPlayer alloc] init]];
    [ocp loadPlugins];

}

@end
