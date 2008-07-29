/*  <title>ETLayoutItemBuilder</title>

	ETLayoutItemBuilder.m
	
	<abstract>Builder classes that can render document formats or object graphs
	into a layout item tree.</abstract>
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  November 2007
 
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
	* Neither the name of the Etoile project nor the names of its contributors
	  may be used to endorse or promote products derived from this software
	  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
	THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <EtoileUI/ETLayoutItemBuilder.h>
#import <EtoileUI/ETLayoutItem.h>
#import <EtoileUI/ETLayoutItem+Factory.h>
#import <EtoileUI/ETLayoutItemGroup.h>
#import <EtoileUI/ETWindowItem.h>
#import <EtoileUI/ETLayer.h>
#import <EtoileUI/ETView.h>
#import <EtoileUI/ETContainer.h>
#import <EtoileUI/NSWindow+Etoile.h>
#import <EtoileUI/ETCompatibility.h>


/** By inheriting from ETFilter, ETTransform instances can be chained together 
	in a filter/transform unit. For example, you can combine several tree 
	renderers into a new renderer to implement a new transform. */
@implementation ETLayoutItemBuilder

+ (id) builder
{
	return AUTORELEASE([[[self class] alloc] init]);
}

@end

/** Generates a layout item tree from an AppKit-based application */
@implementation ETEtoileUIBuilder

- (id) renderPasteboard: (NSPasteboard *)pasteboard
{
	//ETPickboard *pickboard = nil;
	
	return nil;
}

- (id) renderApplication: (id)app
{
	id windowLayer = [ETLayoutItem windowGroup];
	NSEnumerator *e = [[app windows] objectEnumerator];
	NSWindow *window = nil;
	id item = nil;

	/* Build window items */
	while ((window = [e nextObject]) != nil)
	{
		if ([window isVisible] && [window isSystemPrivateWindow] == NO)
		{
			item = [self renderWindow: window];
			//ETLog(@"Rendered window %@ visibility %d into %@", window, [window isVisible], item);
			[windowLayer addItem: item];
		}
	}
	
	/* Build pickboards */
	/*[windowLayer addItem: 
		[self renderPasteboard: [NSPasteboard generalPasteboard]]];*/

	return windowLayer;	
}

#if 1
- (id) renderWindow: (id)window
{
	id item = [self renderView: [window contentView]];
	id windowDecorator = [item windowDecoratorItem];

	//[windowDecorator setRepresentedObject: window];
	/* Decorate only if needed */
	if (windowDecorator == nil)
	{
		windowDecorator = [ETWindowItem itemWithWindow: window];
		[[item lastDecoratorItem] setDecoratorItem: windowDecorator];
	}

	return item;
}
#else
- (id) renderWindow: (id)window
{
	id contentView = [window contentView];
	id item = nil;
	
	RETAIN(contentView);
	//[window setContentView: nil];
	item = [self renderView: contentView];
	[window setContentView: [item displayView]];
	RELEASE(contentView);
	
	//id container = [[ETContainer alloc] initWithFrame: [contentView frame]];
	//[window setContentView: container];
	
	//id childItem = [[[ETContainer alloc] initWithFrame: [contentView frame]] layoutItem];
	//id childItem = [ETLayoutItem layoutItemGroupWithView: [[NSSlider alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)]];
	//[window setContentView: [childItem displayView]];
	
	//[window setContentView: [item view]];
	
	//[[item displayView] addSubview: [[NSSlider alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)]];
	
	return item;
}
#endif

/* When we encounter an EtoileUI native (ETView subclasses), we only return
   the proper layout item, either the item bound to the view or the first 
   decorated item if the view is used as a decorator. We never render 
   subviews of native views since we expect their content is properly set up 
   in term of layout item tree. All other views (other NSView subclasses) 
   are rendered recursively until the end of their view hierachy (-subviews
   returns an empty arrary). */
- (id) renderView: (id)view
{

	if ([view isKindOfClass: [NSScrollView class]])
	{
		ETScrollView *scrollViewWrapper = [[ETScrollView alloc] initWithMainView: view layoutItem: nil];
		id scrollDecorator = [scrollViewWrapper layoutItem];
		id documentViewItem = [self renderView: [view documentView]];

		[documentViewItem setDecoratorItem: scrollDecorator];
		
		return documentViewItem;
	}
	else if ([view isKindOfClass: [ETScrollView class]])
	{
		return [[view layoutItem] firstDecoratedItem];
	}
	else if ([view isKindOfClass: [ETView class]] || [view isContainer])
	{
		return [view layoutItem];
	}
	else if ([view isMemberOfClass: [NSView class]])
	{
		//id superview = [view superview];
		id container = [[ETContainer alloc] initWithFrame: [view frame]];
		id item = [container layoutItem]; //[ETLayoutItem layoutItemGroupWithView: container];
		//return item;
		// NOTE: -addItem: moves subview when subviews is enumerated, hence we have
		// to iterate over a separate collection which isn't mutated.
		// May be we could avoid moving subviews in -addItem: when they are 
		// going to be reinserted at the location where they have been removed.
		NSEnumerator *e = [[NSArray arrayWithArray: [view subviews]] objectEnumerator];
		NSView *subview = nil;
		
		/*[container setAutoresizesSubviews: YES];
		[container setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];*/
		[container setFlipped: [view isFlipped]];
		[container setEnablesHitTest: YES];

		while ((subview = [e nextObject]) != nil)
		{
			RETAIN(subview);
			id childItem = [self renderView: subview];
			[item addItem: childItem];
			//[container addSubview: [childItem displayView]];
			//[container addSubview: subview];
			RELEASE(subview);
		}
		
		//[superview addSubview: [item displayView]];
				
		return item;
	}
	else
	{
		//id superview = [view superview];
		id item = nil;
		
		RETAIN(view);
		item = [ETLayoutItem layoutItemWithView: view];
		RELEASE(view);
		
		//[superview addSubview: [item displayView]];
		
		return item;
	}
}

- (id) renderMenu: (id)menu
{
	return nil;
}

@end