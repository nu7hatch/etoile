/**	<title>ETStyleGroup</title>

	<abstract>A collection of ETStyle objects to be drawn in a given order.</abstract>

	Copyright (C) 2009 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <EtoileFoundation/ETCollection.h>
#import <EtoileUI/ETStyle.h>

@class ETLayoutItem;

/** ETStyleGroup represents a collection of styles you want to render together. 
With a style group, several style aspects can be attached to a layout item with 
-[ETLayoutItem setStyleGroup:] and rendered in a precise order. 

The order in which styles are inserted is used as the compositing order. From 
-firstStyle to -lastStyle, each style is rendered over the previously rendered 
style.

Styles can be reordered and swapped in and out to easily change at runtime how 
a document or an UI looks.

Both basic styles and style groups can be inserted in a style group, which 
means a style can be also organized in a tree structure. 

Each layout item is initialized with its own ETStyleGroup instance and not a 
shared instance. Style groups can be used as shared style objects too though.  */
@interface ETStyleGroup : ETStyle <ETCollectionMutation>
{
	@private
	NSMutableArray *_styles;
}

- (id) init;
- (id) initWithStyle: (ETStyle *)aStyle;
- (id) initWithCollection: (id <ETCollection>)styles;

/* Style Collection */

- (void) addStyle: (ETStyle *)aStyle;
- (void) insertStyle: (ETStyle *)aStyle atIndex: (int)anIndex;
- (void) removeStyle: (ETStyle *)aStyle;
- (void) removeAllStyles;
- (BOOL) containsStyle: (ETStyle *)aStyle;
- (id) firstStyle;
- (id) firstStyleOfClass: (Class)aStyleClass;
- (id) lastStyle;

/* Style Rendering */

- (void) render: (NSMutableDictionary *)inputValues 
     layoutItem: (ETLayoutItem *)item 
	  dirtyRect: (NSRect)dirtyRect;

- (void) didChangeItemBounds: (NSRect)bounds;

/* Collection Protocol */

- (BOOL) isOrdered;
- (BOOL) isEmpty;
- (NSUInteger) count;
- (NSArray *) contentArray;
- (void) addObject: (id)anObject;
- (void) insertObject: (id)anObject atIndex: (unsigned int)anIndex;
- (void) removeObject: (id)anObject;
	  
@end

