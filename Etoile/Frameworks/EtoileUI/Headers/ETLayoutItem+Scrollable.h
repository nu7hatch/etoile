/*
	ETLayoutItem+Scrollable.h

	Syntactic sugar to insert and remove scrollers very easily on a layout item.

	Copyright (C) 2009 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  April 2009

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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <EtoileUI/ETLayoutItem.h>

/* This ETLayoutItem category manages ETScrollAreaItem insertion and removal in 
the receiver decorator chain. You can use it rather than interacting directly 
with a scrollable area decorator you set up and remove manually.

By altering the scroller visibility with this category, you can be sure you 
won't have to reconfigure the scrollable area item even when the decorator is 
fully removed from the receiver decorator chain. An ETScrollAreaItem instance is 
cached as a reusable decorator, which will be reinserted when scrollers are 
reenabled.  */
@interface ETLayoutItem (Scrollable)

- (BOOL) letsLayoutControlsScrollerVisibility;
- (void) setLetsLayoutControlsScrollerVisibility: (BOOL)layoutControl;
- (BOOL) hasVerticalScroller;
- (void) setHasVerticalScroller: (BOOL)scroll;
- (BOOL) hasHorizontalScroller;
- (void) setHasHorizontalScroller: (BOOL)scroll;
- (NSScrollView *) scrollView;
- (BOOL) isScrollViewShown;

// TODO: Remove...
- (void) setShowsScrollView: (BOOL)show;
- (BOOL) isContainerScrollViewInserted;
- (void) unhidesScrollViewDecoratorItem;
- (void) hidesScrollViewDecoratorItem;

@end
