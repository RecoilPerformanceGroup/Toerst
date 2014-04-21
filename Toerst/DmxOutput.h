//
//  DmxOutput.h
//  Toerst
//
//  Created by Recoil Performance Group on 21/02/13.
//  Copyright (c) 2013 HalfdanJ. All rights reserved.
//

#import <ofxCocoaPlugins/ofxCocoaPlugins.h>
#import "DmxPro.h"

@interface DmxOutput : ofPlugin{
    DmxPro * dmxPro;
    
    BOOL _isConnected;
    
    ofxOscSender * oscSender;
    ofxOscSender * oscSenderProj;

}

@property BOOL isConnected;

@end
