//
//  ParameterRecorder.m
//  Toerst
//
//  Created by Recoil Performance Group on 12/02/13.
//  Copyright (c) 2013 HalfdanJ. All rights reserved.
//

#import "ParameterRecorder.h"
#import "ParticleSystem.h"

@implementation ParameterRecorder
@synthesize timelines = _timelines;

-(void)initPlugin{
    self.timelines = [NSMutableArray array];
    
    ParticleSystem * particles = GetPlugin(ParticleSystem);
    
    NumberProperty * propX = [[particles properties] objectForKey:@"shaderAnimalPosX"];
    NumberProperty * propY = [[particles properties] objectForKey:@"shaderAnimalPosY"];
    
    [self.timelines addObject:[@{@"PropertyX":propX, @"PropertyY":propY, @"frames":[@[] mutableCopy]} mutableCopy]];
    
    [self addPropB:@"record"];
    [self addPropB:@"play"];
    [self addPropF:@"currentTime"];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if(object == Prop(@"play")){
        if(PropB(@"play")){
            SetPropF(@"currentTime", 0);
        }
    }
    if(object == Prop(@"record")){
        if(PropB(@"record")){
            for(NSMutableDictionary * dict in self.timelines){
                [dict setValue:[@[] mutableCopy] forKey:@"frames"];
            }
            
            SetPropF(@"currentTime", 0);
            
        }
    }
}

-(void)update:(NSDictionary *)drawingInformation{
    CachePropB(play);
    CachePropB(record);
    CachePropF(currentTime);
    //float prevTime = currentTime;
    
    if(play || record){
        currentTime += 1.0/ofGetFrameRate();
        SetPropF(@"currentTime", currentTime);
    }
    
    if(play){
        for(NSDictionary * dict in self.timelines){
            NumberProperty * propX = [dict objectForKey:@"PropertyX"];
            NumberProperty * propY = [dict objectForKey:@"PropertyY"];
            
            NSArray * frames = [dict objectForKey:@"frames"];
            for(NSDictionary * frame in frames){
                if([[frame valueForKey:@"time"] floatValue] > currentTime){
                    [propX setFloatValue:[[frame valueForKey:@"x"] floatValue]];
                    [propY setFloatValue:[[frame valueForKey:@"y"] floatValue]];
                    break;
                }
            }
        }
    }
    
    if(record){
        SetPropB(@"play", NO);
        
        for(NSDictionary * dict in self.timelines){
            NumberProperty * propX = [dict objectForKey:@"PropertyX"];
            NumberProperty * propY = [dict objectForKey:@"PropertyY"];
            
            NSDictionary * frame = @{
            @"time" : @(currentTime) ,
            @"x" : @([propX floatValue]),
            @"y" : @([propY floatValue])
            };
            
            [[dict objectForKey:@"frames"] addObject:frame];
        }
    }
    
}

-(void)controlDraw:(NSDictionary *)drawingInformation{
    CachePropF(currentTime);
    
    ofBackground(0, 0, 0);
    
    for(NSDictionary * dict in self.timelines){
        NSArray * frames = [dict objectForKey:@"frames"];
        for(NSDictionary * frame in frames){
            if([[frame valueForKey:@"time"] floatValue] > currentTime){
                ofSetColor(255, 255, 255);
                ofNoFill();
                ofCircle([[frame valueForKey:@"x"] floatValue]*ofGetWidth(), [[frame valueForKey:@"y"] floatValue]*ofGetHeight(), 10);
                break;
            }
        }
        
        
        NumberProperty * propX = [dict objectForKey:@"PropertyX"];
        NumberProperty * propY = [dict objectForKey:@"PropertyY"];
        
        ofSetColor(255, 0, 0);
        ofNoFill();
        
        ofCircle([propX floatValue]*ofGetWidth(), [propY floatValue]*ofGetHeight(), 10);
        ofFill();
    }
}

-(void)willSave{
    for(NSMutableDictionary * dict in self.timelines){
        NumberProperty * propX = [dict objectForKey:@"PropertyX"];
        NumberProperty * propY = [dict objectForKey:@"PropertyY"];

        
        [dict setValue:propX.pluginName forKey:@"pluginName"];
        [dict setValue:propX.name forKey:@"nameX"];
        [dict setValue:propY.name forKey:@"nameY"];
    }
    [self.customProperties setObject:self.timelines forKey:@"timelines"];
}

-(void)customPropertiesLoaded{
    if([self.customProperties objectForKey:@"timelines"]){
        self.timelines = [self.customProperties objectForKey:@"timelines"];
        
        for(NSMutableDictionary * dict in self.timelines){
            ofPlugin * plugin =  [globalController getPlugin:NSClassFromString([dict valueForKey:@"pluginName"])];
            
            if([dict valueForKey:@"pluginName"]){
                NSAssert1(plugin, @"No plugin %@",[dict valueForKey:@"pluginName"]);
                
                NumberProperty * propX = [[plugin properties] objectForKey:[dict valueForKey:@"nameX"]];
                NumberProperty * propY = [[plugin properties] objectForKey:[dict valueForKey:@"nameY"]];
                
                [dict setValue:propX forKey:@"PropertyX"];
                [dict setValue:propY forKey:@"PropertyY"];
            }
        }
    }
}

@end
