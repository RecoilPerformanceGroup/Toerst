//
//  NanoKontrol.m
//  Toerst
//
//  Created by Recoil Performance Group on 13/02/13.
//  Copyright (c) 2013 HalfdanJ. All rights reserved.
//

#import "NanoKontrol.h"

@implementation NanoKontrol
@synthesize allProperties = _allProperties;

-(void)initPlugin{
    
    self.allProperties = [NSMutableDictionary dictionary];
    
    
    for(int i=0;i<8;i++){
        PluginProperty * prop = [self addPropF:[NSString stringWithFormat:@"korg%i",i]];
        [prop setMidiChannel:@(1)];
        [prop setMidiNumber:@(i)];
        [self.allProperties setObject:@{@"korgProp": prop,@"number":@(i), @"prop":@(0)} forKey:@(i)];
    }
    for(int i=16;i<24;i++){
        PluginProperty * prop = [self addPropF:[NSString stringWithFormat:@"korg%i",i]];
        [prop setMidiChannel:@(1)];
        [prop setMidiNumber:@(i)];
        [self.allProperties setObject:@{@"korgProp": prop,@"number":@(i), @"prop":@(0)} forKey:@(i)];
    }
    for(int i=41;i<46;i++){
        PluginProperty * prop = [self addPropB:[NSString stringWithFormat:@"korg%i",i]];
        [prop setMidiChannel:@(1)];
        [prop setMidiNumber:@(i)];
        [self.allProperties setObject:@{@"korgProp": prop,@"number":@(i), @"prop":@(0)} forKey:@(i)];
    }

    
    //Qlab 
    for(int i=32;i<=39;i++){
        PluginProperty * prop = [self addPropB:[NSString stringWithFormat:@"korg%i",i]];
        [prop setMidiChannel:@(1)];
        [prop setMidiNumber:@(i)];
        
        NSMutableDictionary * copy = [[self.allProperties objectForKey:@(i-16)] mutableCopy];
        [copy setObject:prop forKey:@"qlabProp"];
        
        [self.allProperties setObject:copy forKey:@(i-16)];
    }
    for(int i=64;i<=71;i++){
        PluginProperty * prop = [self addPropB:[NSString stringWithFormat:@"korg%i",i]];
        [prop setMidiChannel:@(1)];
        [prop setMidiNumber:@(i)];
        
        NSMutableDictionary * copy = [[self.allProperties objectForKey:@(i-64)] mutableCopy];
        [copy setObject:prop forKey:@"qlabProp"];
        
        [self.allProperties setObject:copy forKey:@(i-64)];
    }

}



-(void)awakeFromNib{
    
    for(int i=0;i<21;i++){
        int num = i;
        NSRect rect, rect2;
        int align = NSRightTextAlignment;
        if(i < 8){
            num = i;
            rect = NSMakeRect(355, 185 + (i)*42, 100, 26);
            rect2 = NSMakeRect(455, 185-10 + (i)*42, 100, 40);
            align = NSLeftTextAlignment;
        } else if(i < 16){
            num = i+8;
            rect = NSMakeRect(100, 185 + (i-8)*42, 100, 26);
            rect2 = NSMakeRect(0, 185-10 + (i-8)*42, 100, 40);
        } else if(i < 21){
            num = i-16+41;
            rect = NSMakeRect(355, 36 + (i-16)*24, 100, 26);
            rect2 = NSMakeRect(455, 36-10 + (i-16)*24, 100, 40);
            align = NSLeftTextAlignment;
        }
        
        
        NSPopUpButton * button = [[NSPopUpButton alloc] initWithFrame:rect pullsDown:YES];
        [button addItemWithTitle:@"Select..."];
        
        NSMenu * menu = [button menu];

        
        for(NSDictionary * group in globalController.plugins){
            for(ofPlugin * plugin in [group objectForKey:@"children"]){
                NSMenuItem * item = [menu addItemWithTitle:plugin.name action:nil keyEquivalent:@""];
                NSMenu * submenu = [[NSMenu alloc] initWithTitle:@""];
                
                NSArray * keys = [[plugin.properties allKeys] sortedArrayUsingSelector:@selector(compare:)];
                
                for( NSString * key in keys){
                    PluginProperty * prop = [plugin.properties objectForKey:key];
                    NSMenuItem * subitem = [submenu addItemWithTitle:prop.name action:nil keyEquivalent:@""];
                    [subitem setTarget:self];
                    [subitem setAction:@selector(selectItem:)];
                    subitem.representedObject = @{@"property":prop, @"number":@(num)};
                }
                [menu setSubmenu:submenu forItem:item];
                
            }
        }
        [self.view addSubview:button];
        
        NSTextField * label= [[NSTextField alloc] initWithFrame:rect2];
        [label setDrawsBackground:NO];
        [label setEditable:NO];
        [label setStringValue:@"-"];
        [label setBezeled:NO];
        [label setAlignment:align];
        
        NSMutableDictionary * dict = [[self.allProperties objectForKey:@(num)] mutableCopy];
        [dict setValue:label forKey:@"label"];
        [self.allProperties setObject:dict forKey:@(num)];
        
        [self.view addSubview:label];
        
        

    }
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if([object isKindOfClass:[PluginProperty class]]){
        PluginProperty * prop = object;
        
        for(NSDictionary * dict in [self.allProperties allValues]){
            if([dict objectForKey:@"korgProp"] == prop){
                PluginProperty * korgProp = prop;

                PluginProperty * extProp = [dict objectForKey:@"prop"];
                if([extProp isKindOfClass:[PluginProperty class]]){
                    [extProp midiEvent:[[korgProp midiValue] intValue]];
                }
                
                break;
            }
            
            if([dict objectForKey:@"qlabProp"] == prop){
                PluginProperty * qlabProp = prop;
                if([qlabProp boolValue]){
                    PluginProperty * extProp = [dict objectForKey:@"prop"];
                    if([extProp isKindOfClass:[PluginProperty class]]){
                        [extProp sendQlab];
                    }
                    
                    [qlabProp setValue:@(NO)];
                }
                break;
            }
            
            
        }
    }
}


-(void) selectItem:(id)sender{
    NSDictionary * rep = [sender valueForKey:@"representedObject"];
    PluginProperty * extProp = [rep objectForKey:@"property"];
    
    NSMutableDictionary * dict = [[self.allProperties objectForKey:[rep valueForKey:@"number"]] mutableCopy];
    
    NSTextField * label = [dict objectForKey:@"label"];
    [label setStringValue:[NSString stringWithFormat:@"%@ %@", extProp.pluginName, extProp.name]];
    
    
    [dict setObject:extProp forKey:@"prop"];
    
    [self.allProperties setObject:dict forKey:[rep valueForKey:@"number"]];
    
    PluginProperty * korgProp = [self.properties objectForKey:[NSString stringWithFormat:@"korg%@",[rep objectForKey:@"number"] ]];
    [korgProp setName:extProp.name];

}

-(void)willSave{
    NSMutableArray * arr = [NSMutableArray array];
    
    for(NSDictionary * dict in [self.allProperties allValues]){
        PluginProperty * extProp = [dict valueForKey:@"prop"];
        NSString * extPropName = @"";
        NSString * extPropPlugin = @"";
        if([extProp isKindOfClass:[PluginProperty class]]){
            extPropName = extProp.name;
            extPropPlugin = extProp.pluginName;
        }
        
        [arr addObject:@{
         @"number": [dict valueForKey:@"number"],
         @"extPropName": extPropName,
         @"extPropPlugin": extPropPlugin
         }];
    }
    
    [self.customProperties setObject:arr forKey:@"korg"];
    
}

-(void)customPropertiesLoaded{
    for(NSDictionary * loadedDict in [self.customProperties objectForKey:@"korg"]){
        for(NSDictionary * newDict in [self.allProperties allValues]){
            if([[newDict objectForKey:@"number"] intValue] == [[loadedDict objectForKey:@"number"] intValue]){
                
                NSMutableDictionary * copy = [newDict mutableCopy];
                if([[loadedDict objectForKey:@"extPropName"] length] > 0){
                    ofPlugin * plugin = [globalController getPlugin:NSClassFromString([loadedDict valueForKey:@"extPropPlugin"])];
                    PluginProperty * property = [plugin.properties objectForKey:[loadedDict valueForKey:@"extPropName"]];
                    
                    [copy setObject:property forKey:@"prop"];
                    
                    [self.allProperties setObject:copy forKey:[newDict objectForKey:@"number"]];
                    
                    
                    NSTextField * label = [copy objectForKey:@"label"];
                    [label setStringValue:[NSString stringWithFormat:@"%@ %@", property.pluginName, property.name]];
                    
                    
                    PluginProperty * korgProp = [self.properties objectForKey:[NSString stringWithFormat:@"korg%@",[newDict objectForKey:@"number"] ]];
                    [korgProp setName:property.name];

                }
                
            }
        }
    }
}

@end 
