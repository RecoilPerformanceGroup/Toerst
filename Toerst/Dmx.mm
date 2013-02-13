//
//  Dmx.m
//  Toerst
//
//  Created by Recoil Performance Group on 11/02/13.
//  Copyright (c) 2013 HalfdanJ. All rights reserved.
//

#import "Dmx.h"

@implementation Dmx

-(void)initPlugin{
    for(int i=0;i<16;i++){
        [[self addPropF:[NSString stringWithFormat:@"channel%02i", i+1]] setMaxValue:255];
    }
    
    oscSender = new ofxOscSender;
    oscSender->setup("255.255.255.255", 1313);
    
    
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    for(int i=0;i<16;i++){
        NSString * prop = [NSString stringWithFormat:@"channel%02i", i+1];
        if(object == Prop(prop)){
            ofxOscMessage msg;
            msg.setAddress("/channel/set");
            msg.addIntArg(i+1);
            msg.addIntArg(PropI(prop));
            
            ofxOscBundle bundle;
            bundle.addMessage(msg);
            oscSender->sendBundle(bundle);
            
        }
    }
}

-(void)update:(NSDictionary *)drawingInformation{
}


@end
