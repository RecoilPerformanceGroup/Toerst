//
//  AppDelegate.h
//  Toerst
//
//  Created by Jonas Jongejan on 07/11/12.
//  Copyright (c) 2012 HalfdanJ. All rights reserved.
//
#import <ofxCocoaPlugins/ofxCocoaPlugins.h>

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>{
    ofxCocoaPlugins *ocp;
    IBOutlet  NSWindow *window;
}


@end
