//
//  AppDelegate.m
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//

#import "AppDelegate.h"

#import "ParticleSystem.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    ocp = [[ofxCocoaPlugins alloc] initWithAppDelegate:self];
    //   [ocp setNumberOutputviews:0];
    
    [ocp addHeader:@"Setup"];
    
    [ocp addPlugin:[[Midi alloc] init]];
    [ocp addPlugin:[[Keystoner alloc] initWithSurfaces:[NSArray arrayWithObjects:@"Floor", @"Triangle", nil]] midiChannel:2 ];
    [ocp addPlugin:[[OSCControl alloc] init]];
    
    [ocp addPlugin:[[ParticleSystem alloc] init]];
    
    [ocp loadPlugins];

}

@end
