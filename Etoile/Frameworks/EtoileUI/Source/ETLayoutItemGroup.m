/*  <title>ETLayoutItemGroup</title>

	ETLayoutItemGroup.m
	
	<abstract>Description forthcoming.</abstract>
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  May 2007
 
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

#import <EtoileFoundation/NSObject+Model.h>
#import <EtoileUI/ETLayoutItemGroup.h>
#import <EtoileUI/ETLayoutItemGroup+Mutation.h>
#import <EtoileUI/ETLayoutItem+Factory.h>
#import <EtoileUI/ETFlowLayout.h>
#import <EtoileUI/ETLineLayout.h>
#import <EtoileUI/ETContainer.h>
#import <EtoileUI/ETContainer+Controller.h>
#import <EtoileUI/NSView+Etoile.h>
#import <EtoileUI/ETCompatibility.h>

#define DEFAULT_FRAME NSMakeRect(0, 0, 50, 50)

@interface ETLayoutItem (SubclassVisibility)
- (void) setDisplayView: (ETView *)view;
@end

@interface ETLayoutItemGroup (ETSource)
- (ETContainer *) container;
- (BOOL) isReloading;
- (NSArray *) itemsFromSource;
- (NSArray *) itemsFromFlatSource;
- (NSArray *) itemsFromTreeSource;
@end

@interface ETContainer (PackageVisibility)
- (int) checkSourceProtocolConformance;
- (void) syncDisplayViewWithContainer;
@end

@interface ETLayoutItemGroup (Private)
- (id) initWithItems: (NSArray *)layoutItems view: (NSView *)view value: (id)value representedObject: (id)repObject;
- (BOOL) hasNewLayout;
- (void) setHasNewLayout: (BOOL)flag;
- (void) collectSelectionIndexPaths: (NSMutableArray *)indexPaths;
- (void) applySelectionIndexPaths: (NSMutableArray *)indexPaths;

/* Deprecated (DO NOT USE, WILL BE REMOVED LATER) */
- (id) initWithLayoutItems: (NSArray *)layoutItems view: (NSView *)view value: (id)value;
- (id) initWithLayoutItems: (NSArray *)layoutItems view: (NSView *)view;
@end


@implementation ETLayoutItemGroup

/* Initialization */

/** Designated initializer */
- (id) initWithItems: (NSArray *)layoutItems view: (NSView *)view value: (id)value representedObject: (id)repObject
{
    self = [super initWithView: view value: value representedObject: repObject];
    
    if (self != nil)
    {
		_layoutItems = [[NSMutableArray alloc] init];
		if (layoutItems != nil)
			[self addItems: layoutItems];
		_layout = nil;
		[self setStackedItemLayout: AUTORELEASE([[ETFlowLayout alloc] init])];
		[self setUnstackedItemLayout: AUTORELEASE([[ETLineLayout alloc] init])];
		_isStack = NO;
		_autolayout = YES;
		_usesLayoutBasedFrame = NO;
		[self setHasNewLayout: NO];
		[self setHasNewContent: NO];
		[self setShouldMutateRepresentedObject: YES];
    }
    
    return self;
}

/* Overriden ETLayoutItem designated initializer */
- (id) initWithView: (NSView *)view value: (id)value representedObject: (id)repObject
{
	return [self initWithItems: nil view: view value: value representedObject: repObject];
}

- (id) initWithItems: (NSArray *)layoutItems view: (NSView *)view
{
	return [self initWithItems: layoutItems view: view value: nil representedObject: nil];
}

- (id) init
{
	return [self initWithItems: nil view: nil];
}

- (void) dealloc
{
	DESTROY(_layout);
	DESTROY(_stackedLayout);
	DESTROY(_unstackedLayout);
	DESTROY(_layoutItems);
	
	[super dealloc];
}

- (id) copyWithZone: (NSZone *)zone
{
	ETLayoutItemGroup *item = (ETLayoutItemGroup *)[(id)super copyWithZone: zone];
	
	item->_layoutItems = [[NSMutableArray alloc] init];
	
	// NOTE: Layout objects must be copied because they support only one layout 
	// context. If you share a layout like that: 
	// [item setLayout: [self layout]];
	// -[ETLayoutItemGroup setLayout:] will set the item copy as the layout 
	// context replacing the current value of -[[self layout] layoutContext].
	// This latter value is precisely self.
	/*[item setLayout: [[self layout] layoutPrototype]];
	[item setStackedItemLayout: [[self stackedItemLayout] layoutPrototype]];
	[item setUnstackedItemLayout: [[self unstackedItemLayout] layoutPrototype]];*/
	item->_isStack = [self isStack];
	item->_autolayout = [self isAutolayout];
	item->_usesLayoutBasedFrame = [self usesLayoutBasedFrame];
			
	return item;
}

- (id) deepCopy
{
	ETLayoutItemGroup *item = [super deepCopy];
	NSArray *copiedChildItems = [[self items] valueForKey: @"deepCopy"];
	
	[item addItems: copiedChildItems];
	// TODO: Test if using -autorelease instead of -release results in a quicker 
	// deep copy (when plenty of items are involved).
	[copiedChildItems makeObjectsPerformSelector: @selector(release)];
	
	return item;
}

/* Property Value Coding */

- (NSArray *) properties
{
	NSArray *properties = [NSArray arrayWithObjects: @"layout", nil];
	
	return [[super properties] arrayByAddingObjectsFromArray: properties];
}

/* Finding Container */

- (BOOL) isGroup
{
	return YES;
}

- (BOOL) isContainer
{
	return [[self view] isKindOfClass: [ETContainer class]];
}

/** Returns the first ancestor container that declares a represented path. The 
	ancestor layout item that owns this container is known as the base item 
	(see -baseItem). The base item is usually in charge of coordinating the 
	event handling and the loading of layout items which are provided by a 
	source. */
- (ETContainer *) baseContainer
{
	if ([self isContainer] && [self hasValidRepresentedPathBase])
	{
		return (ETContainer *)[self view];
	}
	else
	{
		return [[self parentLayoutItem] baseContainer];
	}
}

/* Overriden method */
/*- (void) setDisplayView: (ETView *)view
{

}*/

/* Traversing Layout Item Tree */

/** Returns a normal path relative to the receiver by translating index path 
	into a layout item sequence and concatenating the names of all layout items 
	in the sequence. Each index in the index path references a child item by 
	its index in the parent layout item. 
	Resulting path uses '/' as path separator and always begins by '/'. If an 
	item has no name (-name returns nil or an empty string), its index is used 
	instead of the name as a path component.
	For index path 3.4.8.0, a valid translation would be:
	      3     .4 .8   .0
	/BlackCircle/4/Tulip/Zone
	Returns '/' if indexPath is nil or empty. */
- (NSString *) pathForIndexPath: (NSIndexPath *)indexPath
{
	NSString *path = @"/";
	ETLayoutItem *item = self;
	unsigned int index = NSNotFound;
	
	for (unsigned int i = 0; i < [indexPath length]; i++)
	{
		index = [indexPath indexAtPosition: i];
		
		if (index == NSNotFound)
			return nil;

		NSAssert2([item isGroup], @"Item %@ "
			@"must be layout item group to resolve the index path %@", 
			item, indexPath);
		NSAssert3(index < [[(ETLayoutItemGroup *)item items] count], @"Index "
			@"%d in path %@ position %d must be inferior to children item "
			@"number", index + 1, indexPath, i);
			
		item = [(ETLayoutItemGroup *)item itemAtIndex: index];
		if ([item name] != nil && [item isEqual: @""] == NO)
		{
			path = [path stringByAppendingPathComponent: [item name]];
		}
		else
		{
			path = [path stringByAppendingPathComponent: 
				[NSString stringWithFormat: @"%d", index]];	
		}
	}
	
	return path;
}

/** Returns an index path relative to the receiver by translating normal path 
	into a layout item sequence and pushing parent relative index of each 
	layout item in the sequence into an index path. Each index in the index 
	path references a child item by its index in the parent layout item. 
	Resulting path uses internally '.' as path seperator and internally always 
	begins by an index number and not a path seperator. 
	For the translation, empty path component or component made of path 
	separator '/' are skipped in path parameter.
	For index path /BlackCircle/4/Tulip/Zone, a valid translation would be:
	/BlackCircle/4/Tulip/Zone
	      3     .4 .8   .0
	Take note 3.5.8.0 could be a valid translation too because a name could be 
	a number which is unrelated to the item index used by its parent layout 
	item to reference it. */
- (NSIndexPath *) indexPathForPath: (NSString *)path
{
	NSIndexPath *indexPath = AUTORELEASE([[NSIndexPath alloc] init]);
	NSArray *pathComponents = [path pathComponents];
	NSString *pathComp = nil;
	ETLayoutItem *item = self;
	int index = -1;
		
	for (int position = 0; position < [pathComponents count]; position++)
	{
		pathComp = [pathComponents objectAtIndex: position];
	
		if ([pathComp isEqual: @"/"] || [pathComp isEqual: @""])
			continue;

		if ([item isGroup] == NO)
		{
			/* path is invalid */
			indexPath = nil;
			break;
		}
		item = [(ETLayoutItemGroup *)item itemAtPath: pathComp];
		
		/* If no item can be found by interpreting pathComp as an identifier, 
		   try to interpret pathComp as a number */
		if (item == nil)
		{
			index = [pathComp intValue];
			/* -intValue returns 0 when no numeric value is present to be 
			   converted */
			if (index == 0 && [pathComp isEqual: @"0"] == NO)
			{
				/* path is invalid */
				indexPath = nil;
				break;
			}
			
			/* Verify the index truly references a child item */
			if (index >= [[(ETLayoutItemGroup *)item items] count])
			{
				/* path is invalid */
				indexPath = nil;
				break;			
			}
			item = [(ETLayoutItemGroup *)item itemAtIndex: index];
		}
		else
		{
			index = [[item parentLayoutItem] indexOfItem: item];
		}
		
		/*NSAssert1(index == 0 && [pathComp isEqual: @"0"] == NO,
			@"Path components must be indexes for path %@", path);
		NSAssert2([item isGroup], @"Item %@ "
			@"must be layout item group to resolve the index path %@", 
			item, indexPath);
		NSAssert3(index < [[(ETLayoutItemGroup *)item items] count], @"Index "
			@"%d in path %@ position %d must be inferior to children item "
			@"number", index + 1, position, path);*/
		
		indexPath = [indexPath indexPathByAddingIndex: index];
	}	
	
	return indexPath;
}

/** Returns the layout item child identified by the index path paremeter 
	interpreted as relative to the receiver. */
- (ETLayoutItem *) itemAtIndexPath: (NSIndexPath *)path
{
	int length = [path length];
	ETLayoutItem *item = self;
	
	for (unsigned int i = 0; i < length; i++)
	{
		if ([item isGroup])
		{		
			item = [(ETLayoutItemGroup *)item itemAtIndex: [path indexAtPosition: i]];
		}
		else
		{
			item = nil;
			break;
		}
	}
	
	return item;
}

/** Returns the layout item child identified by the path paremeter interpreted 
	as relative to the receiver. 
	Whether the path begins by '/' or not doesn't modify the result. */
- (ETLayoutItem *) itemAtPath: (NSString *)path
{
	NSArray *pathComponents = [path pathComponents];
	NSEnumerator *e = [pathComponents objectEnumerator];
	NSString *pathComp = nil;
	ETLayoutItem *item = self;
	
	while ((pathComp = [e nextObject]) != nil)
	{
		if (pathComp == nil || [pathComp isEqual: @"/"] || [pathComp isEqual: @""])
			continue;
	
		if ([item isGroup])
		{
			item = [[(ETLayoutItemGroup *)item items] firstObjectMatchingValue: pathComp forKey: @"name"];
		}
		else
		{
			item = nil;
			break;
		}
	}
	
	return item;
}

- (NSString *) representedPathBase
{
	NSString *pathBase = nil;
	
	if ([self isContainer])
		pathBase = [(ETContainer *)[self view] representedPath];
		
	return pathBase;
}

/* Manipulating Layout Item Tree */

/** Returns existing subviews of the receiver as layout items. 
	First checks whether the receiver responds to -layoutItem and in such case 
	doesn't already include child items for these subviews. 
	If no, either the subview is an ETView or an NSView 
	instance. When the subview is NSView-based, a new layout item is 
	instantiated by calling +layoutItemWithView: with subview as parameter. 
	Then the new item is automatically inserted as a child item in the layout 
	item representing the receiver. If the subview is ETView-based, the item
	reprensenting the subview is immediately inserted in the receiver item. */
- (NSArray *) itemsWithSubviewsOfView: (NSView *)view
{
	// FIXME: Implement
	return nil;
}

/** This method handles the view visibility of child items with a role similar 
	to -setVisibleItems: that is called by layouts. It is used when you insert 
	an item on an item group without layout, otherwise the view insertion is 
	managed by requesting a layout update which ultimately calls back 
	-setVisibleItems:. 
	Having a null layout class may be a solution to get rid of this. */
- (void) handleAttachViewOfItem: (ETLayoutItem *)item
{
	/* Typically needed if your item has no view and gets added to an item 
	   group without a layout. Without this check -addSuview: [item displayView]
	   results in a crash. */
	if ([item displayView] == nil) /* No view to attach */
		return;

	[[item displayView] removeFromSuperview];
	/* Only insert the item view if the layout is a fixed/free layout and the 
	   receiver has a view itself. 
	   TODO: Probably make more explicit the nil layout check and improve in a
	   way or another the handling of the nil view case. */
	if ([self layout] == nil && [self view] != nil)
		[[self view] addSubview: [item displayView]];
}

/** Symetric method to -handleAttachViewOfItem: */
- (void) handleDetachViewOfItem: (ETLayoutItem *)item
{
	if ([item displayView] == nil) /* No view to detach */
		return;

  	[[item displayView] removeFromSuperview];
}

- (void) handleAttachItem: (ETLayoutItem *)item
{
	RETAIN(item);
	if ([item parentLayoutItem] != nil)
		[[item parentLayoutItem] removeItem: item];
	[item setParentLayoutItem: self];
	RELEASE(item);
	[self handleAttachViewOfItem: item];
}

- (void) handleDetachItem: (ETLayoutItem *)item
{
	[item setParentLayoutItem: nil];
	[self handleDetachViewOfItem: item];
}

/* Marks if needed the receiver as having new content to be layouted, otherwise 
   the layout is told the layout item tree hasn't been mutated. 
   Only valid when the layout item tree is built directly from the represented 
   object by the mean of ETCollection protocol. */
- (void) setRepresentedObject: (id)model
{
	[super setRepresentedObject: model];
	if ([self usesRepresentedObjectAsProvider])
		[self setHasNewContent: YES];
}

/** Returns YES when the item tree mutation are propagated to the represented 
	object, otherwise returns NO if it's up to you to reflect structural changes
	of the layout item tree onto the model object graph. By default, this method 
	returns YES.
	Mutations are triggered by calling children or collection related 
	methods like -addItem:, -insertItem:atIndex:, removeItem:, addObject: etc. 
	WARNING: The returned value is meaningful only if the receiver is a base 
	item. In this case, the value applies to all related descendant items (by
	being inherited through ETLayoutItem and ETLayoutItemGroup implementation). */
- (BOOL) shouldMutateRepresentedObject
{
	return _shouldMutateRepresentedObject;
}

/** Sets whether the layout item tree mutation are propagated to the represented 
	object or not. 
	WARNING: This value set is meaningful only if the receiver is a base item, 
	otherwise the value is simply ignored by ETLayoutItem and ETLayoutItemGroup 
	implementation.  */
- (void) setShouldMutateRepresentedObject: (BOOL)flag
{
	_shouldMutateRepresentedObject = flag;
}

/** Returns YES when the child items are automatically generated by wrapping
	the elements of the represented object collection into ETLayoutItem or 
	ETLayoutItemGroup instances. 
	To use represented objects as providers, you have to set the source of a 
	container to be the layout item bound to it. This item is returned by 
	-[ETContainer layoutItem]. The code would be something like 
	[container setSource: [container layoutItem]].
	WARNING: This value set is meaningful only if the receiver is a base item, 
	otherwise the value is simply ignored by ETLayoutItem and ETLayoutItemGroup 
	implementation. */
- (BOOL) usesRepresentedObjectAsProvider
{
	return ([[[self baseContainer] source] isEqual: [self baseItem]]);
}

/*	Alternatively, if you have a relatively small and static tree structure,
	you can also build the tree by yourself and assigns the root item to the
	container by calling -addItem:. In this case, the user will have the 
	possibility to */
- (void) addItem: (ETLayoutItem *)item
{
	//ETDebugLog(@"Add item in %@", self);
	[self handleAdd: nil item: item];
}

- (void) insertItem: (ETLayoutItem *)item atIndex: (int)index
{
	//ETDebuLog(@"Insert item in %@", self);
	[self handleInsert: nil item: item atIndex: index];
}

- (void) removeItem: (ETLayoutItem *)item
{
	//ETDebugLog(@"Remove item in %@", self);
	[self handleRemove: nil item: item];
}

- (void) removeItemAtIndex: (int)index
{
	ETLayoutItem *item = [_layoutItems objectAtIndex: index];
	[self removeItem: item];
}

- (ETLayoutItem *) itemAtIndex: (int)index
{
	return [_layoutItems objectAtIndex: index];
}

/** Returns the first item in the children of the receiver, with a result 
    identical to [self itemAtIndex: 0].
    Similar to -firstObject method for collections (see ETCollection).*/
- (ETLayoutItem *) firstItem
{
	return [_layoutItems firstObject];
}

/** Returns the last item in the children of the receiver, with a result 
    identical to [self itemAtIndex: [self numberOfItems] - 1].
    Similar to -lastObject method for collections (see ETCollection).*/
- (ETLayoutItem *) lastItem
{
	return [_layoutItems lastObject];
}

- (void) addItems: (NSArray *)items
{
	//ETDebugLog(@"Add items in %@", self);
	[self handleAdd: nil items: items];
}

- (void) removeItems: (NSArray *)items
{
	//ETDebugLog(@"Remove items in %@", self);
	[self handleRemove: nil items: items];
}

- (void) removeAllItems
{
	ETDebugLog(@"Remove all items in %@", self);
	// FIXME: Temporary solution which is quite slow
	[self handleRemove: nil items: [self items]];

#if 0	
	// NOTE: If a selection cache is implemented, the cache must be cleared
	// here because this method doesn't the primitive mutation method 
	// -removeItem:
	
	[_layoutItems makeObjectsPerformSelector: @selector(setParentLayoutItem:) withObject: nil];
	[_layoutItems removeAllObjects];
	if ([self canUpdateLayout])
		[self updateLayout];
#endif
}

// FIXME: (id) parameter rather than (ETLayoutItem *) turns off compiler 
// conflicts with menu item protocol which also implements this method. 
// Fix compiler.
- (int) indexOfItem: (id)item
{
	return [_layoutItems indexOfObject: item];
}

- (BOOL) containsItem: (ETLayoutItem *)item
{
	return ([self indexOfItem: (id)item] != NSNotFound);
}

- (int) numberOfItems
{
	return [_layoutItems count];
}

- (NSArray *) items
{
	return [NSArray arrayWithArray: _layoutItems];
}

/** Returns all children items under the control of the receiver. An item is 
	said to be under the control of an item group when you can traverse the
	branch leading to the item without crossing a parent item which is declared
	as a base item.
	An item group becomes a base item when a represented path base is set, in 
	other words when -representedPathBase doesn't return nil. 
	This method collects every items the layout item subtree (excluding the 
	receiver) by doing a preorder traversal, the resulting collection is a flat
	list of every items in the tree. 
	If you are interested by collecting descendant items in another traversal
	order, you have to implement your own version of this method. */
- (NSArray *) itemsIncludingRelatedDescendants
{
	// TODO: This code is probably quite slow by being written in a recursive 
	// style and allocating/resizing many arrays instead of using a single 
	// linked list. Test whether optimization are needed or not really...
	NSEnumerator *e = [[self items] objectEnumerator];
	id item = nil;
	NSMutableArray *collectedItems = [NSMutableArray array];
	
	while ((item = [e nextObject]) != nil)
	{
		[collectedItems addObject: item];
			
		if ([item isGroup] && [item hasValidRepresentedPathBase] == NO)
			[collectedItems addObjectsFromArray: [item itemsIncludingRelatedDescendants]];
	}
	
	return collectedItems;
}

/** Returns all descendant items of the receiver, including immediate children.
	This method collects every items the layout item subtree (excluding the 
	receiver) by doing a preorder traversal, the resulting collection is a flat
	list of every items in the tree. 
	If you are interested by collecting descendant items in another traversal
	order, you have to implement your own version of this method. */
- (NSArray *) itemsIncludingAllDescendants
{
	// TODO: This code is probably quite slow by being written in a recursive 
	// style and allocating/resizing many arrays instead of using a single 
	// linked list. Test whether optimization are needed or not really ...
	NSEnumerator *e = [[self items] objectEnumerator];
	id item = nil;
	NSMutableArray *collectedItems = [NSMutableArray array];
	
	while ((item = [e nextObject]) != nil)
	{
		[collectedItems addObject: item];
			
		if ([item isGroup])
			[collectedItems addObjectsFromArray: [item itemsIncludingAllDescendants]];
	}
	
	return collectedItems;
}

- (BOOL) canReload
{
	ETContainer *container = [self baseContainer];
	BOOL hasSource = ([container source] != nil);

	return hasSource && ![self isReloading];
}

/** This method can be safely called even if the receiver has no source or 
	doesn't inherit a source from an ancestor. */
- (void) reloadIfNeeded
{
	if ([self canReload])
		[self reload];
}

/** Reloads the content by removing all existing childrens and requesting all
	the receiver immediate children to the source. */
- (void) reload
{
	_reloading = YES;
	
	ETContainer *container = [self baseContainer];
	BOOL hasSource = ([container source] != nil);

	/* Retrieve layout items provided by source */
	if (hasSource)
	{
		NSArray *itemsFromSource = [self itemsFromSource];
		[self removeAllItems];
		[self addItems: itemsFromSource];
	}
	else
	{
		ETLog(@"Impossible to reload %@ because the layout item miss either "
			@"a container %@ or a source %@", self, container, [container source]);
	}
	
	_reloading = NO;
}

/* Layout */

- (BOOL) hasNewLayout { return _hasNewLayout; }

- (void) setHasNewLayout: (BOOL)flag { _hasNewLayout = flag; }

- (ETLayout *) layout
{
	return _layout;
}

- (void) setLayout: (ETLayout *)layout
{
	if (_layout == layout)
		return;

	//ETDebugLog(@"Modify layout from %@ to %@ in %@", _layout, layout, self);
	
	BOOL wasAutolayoutEnabled = [self isAutolayout];
	
	/* Disable autolayout to avoid spurious updates triggered by stuff like
	   view/container frame modification on layout view insertion */
	[self setAutolayout: NO];
	
	[_layout setLayoutContext: nil];
	/* Don't forget to remove existing display view if we switch from a layout 
	   which reuses a native AppKit control like table layout. */
	// NOTE: Be careful of layout objects which can share a common class but 
	// all differs by their unique display view prototype.
	// May be we should move it into -[layout setContainer:]...
	// Triggers scroll view display which triggers layout render in turn to 
	// compute the content size
	if ([self isContainer])
		[(ETContainer *)[self supervisorView] setDisplayView: nil]; 
	ASSIGN(_layout, layout);
	[self setHasNewLayout: YES];
	[layout setLayoutContext: self];
	
	/* if ([_layout representedItem] != nil)
		[[_layoutItem setDecoratorItem: self]; */

	// FIXME: We should move code to set display view when necessary here. By
	// calling -setDisplayView: [_container layoutView] we wouldn't
	// need anymore to call -syncDisplayViewWithContainer here.
	// All display view set up code is currently in -renderWithLayoutItems:
	// of AppKit-based layouts. Part of this code should be put inside 
	// overidden -layoutView method in each ETLayout suclasses.
	if ([self isContainer])
		[(ETContainer *)[self supervisorView] syncDisplayViewWithContainer];
	
	[self setAutolayout: wasAutolayoutEnabled];
	if ([self canUpdateLayout])
		[self updateLayout];
}

/** Returns the first ancestor layout item, including itself, whose layout 
   returns YES to -isOpaque (see ETLayout). If none is found, returns self. */
- (ETLayoutItemGroup *) ancestorItemForOpaqueLayout
{
	ETLayoutItemGroup *parent = self;

	while (parent != nil)
	{
		if ([[parent layout] isOpaque])
			return parent;
		
		parent = [parent parentItem];
	}

	return self; /* Found no ancestor with an opaque layout */
}

/** Attemps to reload the children items from the source and updates the layout 
    by asking the first ancestor item with an opaque layout to do so. */
- (void) reloadAndUpdateLayout
{
	[self reload];
	[[self ancestorItemForOpaqueLayout] updateLayout];
}

// TODO: This code is a little bit messy, refactor...
- (void) updateLayout
{
	if ([self layout] == nil)
		return;
	
	BOOL isNewLayoutContent = ([self hasNewContent] || [self hasNewLayout]);
	
	/* Update layout of descendant items before all because our own layout 
	   depends on the layout of the descendant items. Layout update may modify
	   number and frame of descendant items, thereby producing different layout
	   conditions higher in the hierarchy (like ourself). */
	if ([[self items] count] > 0)
		[[self items] makeObjectsPerformSelector: @selector(updateLayout)];
	
	/* Delegate layout rendering to custom layout object */
	[[self layout] render: nil isNewContent: isNewLayoutContent];
	
	[[self closestAncestorContainer] setNeedsDisplay: YES];
	
	/* Unset needs layout flags */
	[self setHasNewContent: NO];
	[self setHasNewLayout: NO];
	
	// FIXME: Redisplay closestAncestorContainer with our rect
	/*ETContainer *closestContainer = [self closestAncestorContainer];
	NSRect closestViewInsideRect = [closestContainer frame];
	NSRect dirtyRect = [self frame];
	
	closestViewInsideRect.origin = NSZeroPoint;
	if ([self displayView] != nil)
	{
		dirtyRect = [[self displayView] convertRect: dirtyRect toView: closestContainer];
	}
	dirtyRect = NSIntersectionRect(dirtyRect, closestViewInsideRect);
	[closestContainer setNeedsDisplayInRect: dirtyRect];*/
}

- (BOOL) canUpdateLayout
{
	return [self isAutolayout] && ![self isReloading] && ![[self layout] isRendering];
}

- (BOOL) isAutolayout
{
	return _autolayout;
}

- (void) setAutolayout: (BOOL)flag
{
	_autolayout = flag;
}

- (BOOL) usesLayoutBasedFrame
{
	return _usesLayoutBasedFrame;
}

- (void) setUsesLayoutBasedFrame: (BOOL)flag
{
	_usesLayoutBasedFrame = flag;
}

/* Rendering */

- (void) render: (NSMutableDictionary *)inputValues dirtyRect: (NSRect)dirtyRect inView: (NSView *)view 
{
	if ([self usesLayoutBasedFrame] || NSIntersectsRect(dirtyRect, [self frame]))
	{
		NSView *renderView = view;
		
		if ([self displayView] != nil)
			renderView = [self displayView];
		
		if ([[NSView focusView] isEqual: renderView] == NO)
			[renderView lockFocus];
			
		NSAffineTransform *transform = [NSAffineTransform transform];
		
		/* Modify coordinate matrix when the layout item doesn't use a view for 
		   drawing. */
		if ([self displayView] == nil)
		{
			[transform translateXBy: [self x] yBy: [self y]];
			[transform concat];
		}
		
		[[self renderer] renderLayoutItem: self];
		
		if ([self displayView] == nil)
		{
			[transform invert];
			[transform concat];
		}
			
		[view unlockFocus];
		
		/* Render child items */
		
		NSEnumerator *e = [[self items] reverseObjectEnumerator];
		ETLayoutItem *item = nil;
		NSRect newDirtyRect = NSZeroRect;
		
		if ([self displayView] != nil)
		{
			newDirtyRect = NSIntersectionRect(dirtyRect, [[self displayView] frame]);
			[view convertRect: newDirtyRect toView: [self displayView]];
		}
		
		while ((item = [e nextObject]) != nil)
		{
			[item render: inputValues dirtyRect: newDirtyRect inView: renderView];
		}
	}
}

/** Returns the visible child items of the receiver. 
    This is a shortcut method for -visibleItemsForItems:. */
- (NSArray *) visibleItems
{
	return [self visibleItemsForItems: [self items]];
}

/** Sets the visible child items of the receiver, by taking care of inserting
    and removing the item display views based on the visibility of the layout 
    items.
    This is a shortcut method for -visibleItemsForItems:. */
- (void) setVisibleItems: (NSArray *)visibleItems
{
	return [self setVisibleItems: visibleItems forItems: [self items]];
}
/** Returns the visible child items of the receiver. 
    You shouldn't need to call this method by yourself unless you write an 
    ETCompositeLayout subclass which usually requires the receiver displays 
    layout items which doesn't belong to it, as children, but to another item 
    group. */
- (NSArray *) visibleItemsForItems: (NSArray *)items
{
	ETContainer *container = nil;
	NSMutableArray *visibleItems = [NSMutableArray array];
	NSEnumerator  *e = [items objectEnumerator];
	ETLayoutItem *item = nil;
	
	if ([self isContainer])
		container = (ETContainer *)[self view];
	
	while ((item = [e nextObject]) != nil)
	{
		if ([item isVisible])
			[visibleItems addObject: item];
	}
	
	return visibleItems;
}

/** Sets the visible child items of the receiver, by taking care of inserting
    and removing the item display views based on the visibility of the layout 
    items.
    This method is typically called by the layout of the receiver once the 
    layout rendering is finished in order to adjust the visibility of views and 
    update the visible property of the child items. 
    You shouldn't need to call this method by yourself 
    (see -visibleItemsForItems:). */
- (void) setVisibleItems: (NSArray *)visibleItems forItems: (NSArray *)items
{
// FIXME: Make a bottom top traversal to find the first view which can be used 
// as superview for the visible layout item views. Actually this isn't needed
// or supported because all ETLayoutItemGroup instances must embed a container.
// This last point is going to become purely optional.
	ETContainer *container = nil;
	NSEnumerator  *e = [items objectEnumerator];
	ETLayoutItem *item = nil;
	
	if ([self isContainer])
		container = (ETContainer *)[self view];
	
	while ((item = [e nextObject]) != nil)
	{
		if ([visibleItems containsObject: item])
		{
			[item setVisible: YES];
			if (container != nil && [[container subviews] containsObject: [item displayView]] == NO)
			{
				[container addSubview: [item displayView]];
				//ETDebugLog(@"Inserted view at %@", NSStringFromRect([[item displayView] frame]));
			}
		}
		else
		{
			[item setVisible: NO];
			if (container != nil && [[container subviews] containsObject: [item displayView]])
			{
				[[item displayView] removeFromSuperview];
				//ETDebugLog(@"Removed view at %@", NSStringFromRect([[item displayView] frame]));
			}
		}
	}
}

/* Grouping */

- (ETLayoutItemGroup *) makeGroupWithItems: (NSArray *)items
{
	ETLayoutItemGroup *itemGroup = nil;
	ETLayoutItemGroup *prevParent = nil;
	int firstItemIndex = NSNotFound;
	
	if (items != nil && [items count] > 0)
	{
		NSEnumerator *e = [[self items] objectEnumerator];
		ETLayoutItem *item = [e nextObject];
		
		prevParent = [item parentLayoutItem];
		firstItemIndex = [prevParent indexOfItem: item];
		
		/* Try to find a common parent shared by all items */
		while ((item = [e nextObject]) != nil)
		{
			if ([[item parentLayoutItem] isEqual: prevParent] == NO)
			{
				prevParent = nil;
				break;
			}
		}
	}
		
	/* Will reparent each layout item to itemGroup */
	itemGroup = [ETLayoutItemGroup layoutItemGroupWithLayoutItems: items];
	/* When a parent shared by all items exists, inserts new item group where
	   its first item was previously located */
	if (prevParent != nil)
		[prevParent insertItem: itemGroup atIndex: firstItemIndex];
	
	return itemGroup;
}

/** Dismantles the receiver layout item group. If all items owned by the item */
- (NSArray *) unmakeGroup
{
	ETLayoutItemGroup *parent = [self parentLayoutItem];
	NSArray *items = [self items];
	//int itemGroupIndex = [parent indexOfItem: self];
	
	RETAIN(self);
	[parent removeItem: self];
	/* Delay release the receiver until we fully step out of receiver's 
	   instance methods (like this method). */
	AUTORELEASE(self);

	// FIXME: Implement -insertItems:atIndex:
	//[parent insertItems: items atIndex: itemGroupIndex];		
	
	return items;
}

/* Stacking */

+ (NSSize) stackSize
{
	return NSMakeSize(200, 200);
}

- (ETLayout *) stackedItemLayout
{
	return _stackedLayout;
}

- (void) setStackedItemLayout: (ETLayout *)layout
{
	ASSIGN(_stackedLayout, layout);
}

- (ETLayout *) unstackedItemLayout
{
	return _unstackedLayout;
}

- (void) setUnstackedItemLayout: (ETLayout *)layout
{
	ASSIGN(_unstackedLayout, layout);
}

- (void) setIsStack: (BOOL)flag
{
	if (_isStack == NO)
	{
		if ([[self view] isKindOfClass: [ETContainer class]] == NO)
		{
			/*NSRect stackFrame = ETMakeRect(NSZeroPoint, [ETLayoutItemGroup stackSize]);
			ETContainer *container = [[ETContainer alloc] 
				initWithFrame: stackFrame layoutItem: self];*/
			// FIXME: Insert the container on the fly
		}
		[[self container] setItemScaleFactor: 0.7];
		[self setSize: [ETLayoutItemGroup stackSize]];
	}
		
	_isStack = flag;
}

- (BOOL) isStack
{
	return _isStack;
}

- (BOOL) isStacked
{
	return [self isStack] && [[self layout] isEqual: [self stackedItemLayout]];
}

- (void) stack
{
	/* Turn item group into stack if necessary */
	[self setIsStack: YES];
	[self reloadIfNeeded];
	[self setLayout: [self stackedItemLayout]];
}

- (void) unstack
{
	/* Turn item group into stack if necessary */
	[self setIsStack: YES];
	[self reloadIfNeeded];
	[self setLayout: [self unstackedItemLayout]];
}

/* Selection */

- (void) collectSelectionIndexPaths: (NSMutableArray *)indexPaths
{
	NSEnumerator *e = [[self items] objectEnumerator];
	id item = nil;
		
	while ((item = [e nextObject]) != nil)
	{
		if ([item isSelected])
			[indexPaths addObject: [item indexPath]];
		if ([item isGroup])
			[item collectSelectionIndexPaths: indexPaths];
	}
}

/** Returns the index paths of selected items in layout item subtree of the the receiver. */
- (NSArray *) selectionIndexPaths
{
	NSMutableArray *indexPaths = [NSMutableArray array];
	
	[self collectSelectionIndexPaths: indexPaths];
	
	return indexPaths;
}

- (void) applySelectionIndexPaths: (NSMutableArray *)indexPaths
{
	NSEnumerator *e = [[self items] objectEnumerator];
	id item = nil;
		
	while ((item = [e nextObject]) != nil)
	{
		NSIndexPath *itemIndexPath = [item indexPath];
		if ([indexPaths containsObject: itemIndexPath])
		{
			[item setSelected: YES];
			[indexPaths removeObject: itemIndexPath];
		}
		else
		{
			[item setSelected: NO];
		}
		if ([item isGroup])
			[item applySelectionIndexPaths: indexPaths];
	}
}

/** Sets the selected items in the layout item subtree attached to the receiver. 
	TODO: See [ETLayout selectionIndexPaths].*/
- (void) setSelectionIndexPaths: (NSArray *)indexPaths
{
	[self applySelectionIndexPaths: [NSMutableArray arrayWithArray: indexPaths]];
}

/** Returns the selected child items belonging to the receiver. 
	The returned collection only includes immediate children, other selected 
	descendant items below these childrens in the layout item subtree are 
	excluded. */
- (NSArray *) selectedItems
{
	return [[self items] objectsMatchingValue: [NSNumber numberWithBool: YES] forKey: @"isSelected"];
}

/** Returns selected descendant items reported by the active layout through 
	-[ETLayout selectedItems]. 
	You should call this method to obtain the selection in most cases and not
	-selectedItems. */
- (NSArray *) selectedItemsInLayout
{
	NSArray *layoutSelectedItems = [[self layout] selectedItems];
	
	if (layoutSelectedItems != nil)
	{
		return layoutSelectedItems;
	}
	else
	{
		return [self selectedItems];
	}
}

/** You should rarely need to invoke this method. */
- (NSArray *) selectedItemsIncludingRelatedDescendants
{
	NSArray *descendantItems = [self itemsIncludingRelatedDescendants];
	
	return [descendantItems objectsMatchingValue: [NSNumber numberWithBool: YES] forKey: @"isSelected"];
}

/** You should rarely need to invoke this method. */
- (NSArray *) selectedItemsIncludingAllDescendants
{
	NSArray *descendantItems = [self itemsIncludingAllDescendants];
	
	return [descendantItems objectsMatchingValue: [NSNumber numberWithBool: YES] forKey: @"isSelected"];
}

/* Collection Protocol */

- (BOOL) isOrdered
{
	return YES;
}

- (BOOL) isEmpty
{
	return ([self numberOfItems] == 0);
}

- (unsigned int) count
{
	return [self numberOfItems];
}

- (id) content
{
	return [self items];
}

- (NSArray *) contentArray
{
	return [self items];
}

/** Adds object to the child items of the receiver, eventually autoboxing the 
	object if needed.
	If the object is a layout item, it is added directly to the layout items as
	it would be by calling -addItem:. If the object isn't an instance of some
	ETLayoutItem subclass, it gets autoboxed into a layout item that is then 
	added to the child items. 
	Autoboxing means the object is set as the represented object (or value) of 
	the item to be added. If the object replies YES to -isGroup, an 
	ETLayoutItemGroup instance is created instead of instantiating a simple 
	ETLayoutItem. 
	Also if the receiver or the base item bound to it has a container, the 
	instantiated item could also be either a deep copy of -templateItem or 
	-templateItemGroup when such template are available (not nil). -templateItem
	is retrieved when object returns NO to -isGroup, otherwise 
	-templateItemGroup is retrieved (-isGroup returns YES). */
- (void) addObject: (id)object
{
	id item = [object isLayoutItem] ? object : [self itemWithObject: object isValue: [object isCommonObjectValue]];
	
	if ([object isLayoutItem] == NO)
		ETDebugLog(@"Boxed object %@ in item %@ to be added to %@", object, item, self);

	[self addItem: item];
}

- (void) insertObject: (id)object atIndex: (unsigned int)index
{
	id item = [object isLayoutItem] ? object : [self itemWithObject: object isValue: [object isCommonObjectValue]];
	
	if ([object isLayoutItem] == NO)
		ETDebugLog(@"Boxed object %@ in item %@ to be inserted in %@", object, item, self);

	[self insertItem: item atIndex: index];
}

/** Removes object from the child items of the receiver, eventually trying to 
	remove items with represented objects matching the object. */
- (void) removeObject: (id)object
{
	/* Try to remove object by matching it against child items */
	if ([object isLayoutItem] && [self containsItem: object])
	{
		[self removeItem: object];
	}
	else
	{
		/* Remove items with boxed object matching the object to remove */	
		NSArray *itemsMatchedByRepObject = nil;
		
		itemsMatchedByRepObject = [[self items] 
			objectsMatchingValue: object forKey: @"representedObject"];
		[self removeItems: itemsMatchedByRepObject];
		
		itemsMatchedByRepObject = [[self items] 
			objectsMatchingValue: object forKey: @"value"];
		[self removeItems: itemsMatchedByRepObject];
	}
}

- (id) newItem
{
	id item = nil;

	if ([self container] != nil)
	{
		item = [[self container] templateItem];
	}
	else
	{
		item = [[[self baseItem] container] templateItem];
	}

	if (item != nil)
	{
		item = AUTORELEASE([item deepCopy]);
	}
	else
	{
		item = [ETLayoutItem layoutItem];
	}

	return item;
}

- (id) newItemGroup
{
	id item = nil;

	if ([self container] != nil)
	{
		item = [[self container] templateItemGroup];
	}
	else
	{
		item = [[[self baseItem] container] templateItemGroup];
	}

	if (item != nil)
	{
		item = AUTORELEASE([item deepCopy]);
	}
	else
	{
		item = [ETLayoutItemGroup layoutItem];
	}

	return item;
}


- (id) itemWithObject: (id)object isValue: (BOOL)isValue
{
	id item = [object isCollection] ? [self newItemGroup] : [self newItem];

	/* We don't set the object as model when it is nil, so any existing value 
	   or represented object already provided with the item template won't be 
	   overwritten in such case. 
	   Value and represented object are copied when -deepCopy is called on the 
	   template items in -newItem and -newItemGroup. */
	if (object != nil)
	{
		/* If the object is a simple value object rather than a true model object
		we don't set it as represented object but as a value. */
		if (isValue)
		{
			[item setValue: object];
		}
		else
		{
			[item  setRepresentedObject: object];
		}
	}

	return item;
}

/* ETLayoutingContext */

- (float) itemScaleFactor
{
	if ([[self view] respondsToSelector: @selector(itemScaleFactor)])
	{
		return	[(id)[self view] itemScaleFactor];
	}
	else
	{
		ETLog(@"WARNING: Layout item %@ doesn't respond to -itemScaleFactor", self);
		return 0;
	}
}

/* ETLayoutingContext scroll view related methods */

/* -documentVisibleRect size */
- (NSSize) visibleContentSize
{
	if ([[self view] respondsToSelector: @selector(contentSize)])
	{
		return	[(id)[self view] contentSize];
	}
	else if ([[self view] respondsToSelector: @selector(scrollView)]
	 && [[(id)[self view] scrollView] respondsToSelector: @selector(contentSize)])
	{
		return [[(id)[self view] scrollView] contentSize];
	}
	else
	{
		ETLog(@"WARNING: Layout item %@ doesn't respond to -contentSize", self);
		return NSZeroSize;
	}
}

- (BOOL) isScrollViewShown
{
	if ([[self view] respondsToSelector: @selector(isScrollViewShown)])
	{
		return	[(id)[self view] isScrollViewShown];
	}
	else
	{
		ETLog(@"WARNING: Layout item %@ doesn't respond to -isScrollViewShown", self);
		return NO;
	}
}

		/* The frame may be patched by the display view, that's why 
		   _frame = rect would be incorrect. When the display view is embedded
		   inside a scroll view, the display view is the document view of the
		   scroll view and must fit perfectly into it.
		   For more details, see -[ETContainer setFrameSize:] */
- (void) setContentSize: (NSSize)size
{
	if ([[self view] respondsToSelector: @selector(setContentSize:)])
	{
		[(id)[self view] setContentSize: size];
	}
	else if ([[self view] respondsToSelector: @selector(scrollView)]
	 && [[(id)[self view] scrollView] isKindOfClass: [NSScrollView class]])
	{
		[[[(id)[self view] scrollView] documentView] setFrameSize: size];		
	}
	else
	{
		ETLog(@"WARNING: Layout item %@ doesn't respond to -setContentSize:", self);
	}
}

/* Dummy methods to shut down compiler warning about ETLayoutingContext not 
   fully implemented */

- (NSSize) size
{
	return [super size];
}

- (void) setSize: (NSSize)size
{
	[super setSize: size];
}

- (NSView *) view
{
	return [super view];
}

/* Live Development */

- (void) beginEditingUI
{
	/* Notify view and decorator item chain */
	[super beginEditingUI];
	
	/* Notify children */
	[[self items] makeObjectsPerformSelector: @selector(beginEditingUI)];
}

/* Deprecated (DO NOT USE, WILL BE REMOVED LATER) */

- (id) initWithLayoutItems: (NSArray *)layoutItems view: (NSView *)view value: (id)value representedObject: (id)repObject
{
	return [self initWithItems: layoutItems view: view value: value representedObject: repObject];
}

- (id) initWithLayoutItems: (NSArray *)layoutItems view: (NSView *)view
{
	return [self initWithItems: layoutItems view: view];
}

@end

/* Helper methods to retrieve layout items provided by data sources */

@implementation ETLayoutItemGroup (ETSource)

- (ETContainer *) container
{
	if ([self isContainer])
	{
		return (ETContainer *)[self view];
	}
	else
	{
		return nil;
	}
}

- (BOOL) isReloading
{
	return _reloading;
}

- (NSArray *) itemsFromSource
{
	ETContainer *container = [self baseContainer];

	switch ([container checkSourceProtocolConformance])
	{
		case 1:
			//ETDebugLog(@"Will -reloadFromFlatSource");
			return [self itemsFromFlatSource];
			break;
		case 2:
			//ETDebugLog(@"Will -reloadFromTreeSource");
			return [self itemsFromTreeSource];
			break;
		case 3:
			ETDebugLog(@"Will -reloadFromRepresentedObject");
			return [self itemsFromRepresentedObject];
			break;
		default:
			ETLog(@"WARNING: source protocol is incorrectly supported by %@.", [[self container] source]);
	}
	
	return nil;
}

- (NSArray *) itemsFromFlatSource
{
	NSMutableArray *itemsFromSource = [NSMutableArray array];
	ETLayoutItem *layoutItem = nil;
	ETContainer *container = [self baseContainer];
	int nbOfItems = [[container source] numberOfItemsInContainer: container];
	
	for (int i = 0; i < nbOfItems; i++)
	{
		layoutItem = [[container source] container: container itemAtIndex: i];
		[itemsFromSource addObject: layoutItem];
	}
	
	return itemsFromSource;
}

- (NSArray *) itemsFromTreeSource
{
	NSMutableArray *itemsFromSource = [NSMutableArray array];
	ETLayoutItem *layoutItem = nil;
	ETContainer *baseContainer = [self baseContainer];
	// NOTE: [self indexPathFromItem: [container layoutItem]] is equal to [[container layoutItem] indexPathFortem: self]
	NSIndexPath *indexPath = [self indexPathFromItem: [baseContainer layoutItem]];
	int nbOfItems = 0;
	
	//ETDebugLog(@"-itemsFromTreeSource in %@", self);
	
	/* Request number of items to the source by passing receiver index path 
	   expressed in a way relative to the base container */
	nbOfItems = [[baseContainer source] container: baseContainer numberOfItemsAtPath: indexPath];

	for (int i = 0; i < nbOfItems; i++)
	{
		NSIndexPath *indexSubpath = nil;
		
		indexSubpath = [indexPath indexPathByAddingIndex: i];
		/* Request item to the source by passing item index path expressed in a
		   way relative to the base container */
		layoutItem = [[baseContainer source] container: baseContainer itemAtPath: indexSubpath];
		//ETDebugLog(@"Retrieved item %@ known by path %@", layoutItem, indexSubpath);
		if (layoutItem != nil)
		{
			[itemsFromSource addObject: layoutItem];
		}
		else
		{
			[NSException raise: @"ETInvalidReturnValueException" 
				format: @"Item at path %@ returned by source %@ must not be "
				@"nil", indexSubpath, [baseContainer source]];
		}
	}
	
	return itemsFromSource;
}

@end