/** <title>NSView+Etoile</title>

	<abstract>NSView additions.</abstract>

	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  May 2007
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <EtoileFoundation/ETCollection.h>


@interface NSView (Etoile) <NSCopying, ETCollection, ETCollectionMutation>

+ (NSRect) defaultFrame;

- (id) init;
- (BOOL) isWidget;
- (BOOL) isSupervisorView;
- (BOOL) isWindowContentView;

/* Copying */

- (id) copyWithZone: (NSZone *)zone;

/* Collection Protocol */

- (BOOL) isOrdered;
- (BOOL) isEmpty;
- (id) content;
- (NSArray *) contentArray;
- (void) addObject: (id)view;
- (void) insertObject: (id)view atIndex: (unsigned int)index;
- (void) removeObject: (id)view;

/* Frame Utility Methods */

- (float) height;
- (float) width;
- (void) setHeight: (float)height;
- (void) setWidth: (float)width;
- (float) x;
- (float) y;
- (void) setX: (float)x;
- (void) setY: (float)y;

- (void) setFrameSizeFromTopLeft: (NSSize)size;
- (void) setHeightFromTopLeft: (int)height;
- (NSPoint) topLeftPoint;
- (void) setFrameSizeFromBottomLeft: (NSSize)size;
- (void) setHeightFromBottomLeft: (int)height;
- (NSPoint) bottomLeftPoint;

/* Property Value Coding */

- (NSArray *) properties;

/* Basic Properties */

- (NSImage *) snapshot;
- (NSImage *) icon;

@end

@interface NSScrollView (Etoile)
- (BOOL) isWidget;
@end


/* Utility Functions */

NSRect ETMakeRect(NSPoint origin, NSSize size);
NSRect ETScaleRect(NSRect frame, float factor);
NSSize ETScaleSize(NSSize size, float factor);
