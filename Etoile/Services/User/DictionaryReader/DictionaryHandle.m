/*  -*-objc-*-
 *
 *  Dictionary Reader - A Dict client for GNUstep
 *  Copyright (C) 2006 Guenther Noack
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the MIT license. See COPYING.
 */

#import "DictionaryHandle.h"


@implementation DictionaryHandle

+(id) dictionaryFromPropertyList: (NSDictionary*) aPropertyList
{
    DictionaryHandle* dict;
    
    dict = [NSClassFromString([aPropertyList objectForKey: @"class"]) alloc];
    dict = [dict initFromPropertyList: aPropertyList];
    [dict autorelease];
    
    return dict;
}

-(id) initFromPropertyList: (NSDictionary*) aPropertyList
{
    NSAssert([self class] != [DictionaryHandle class],
        @"DictionaryHandle is abstract, don't instantiate it directly!"
    );
    
    if ((self = [super init]) != nil) {
        [self setActive: [[aPropertyList objectForKey: @"active"] intValue]];
    }
    
    return self;
}

-(NSDictionary*) shortPropertyList
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity: 4];
    
    [dict setObject: [isa description] forKey: @"class"];
    [dict setObject: [NSNumber numberWithBool: _active] forKey: @"active"];
    
    return dict;
}

-(BOOL) isActive
{
    return _active;
}

-(void) setActive: (BOOL) isActive
{
    _active = isActive;
}

@end
