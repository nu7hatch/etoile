/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import "COUtility.h"

#define CODeserializer ETDeserializer

@interface ETDeserializer (CODeserializer)
- (void) loadUUID: (char *)anUUID withName: (char *)aName;
@end