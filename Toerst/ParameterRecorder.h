//
//  ParameterRecorder.h
//  Toerst
//
//  Created by Recoil Performance Group on 12/02/13.
//  Copyright (c) 2013 HalfdanJ. All rights reserved.
//

#import <ofxCocoaPlugins/ofxCocoaPlugins.h>

@interface ParameterRecorder : ofPlugin{
    NSMutableArray * _timelines;
}

@property NSMutableArray * timelines;

@end
