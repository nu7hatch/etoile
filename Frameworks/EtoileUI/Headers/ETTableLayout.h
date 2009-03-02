/*
	ETTableLayout.h
	
	Description forthcoming.
 
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <EtoileUI/ETLayout.h>

@class ETLayoutLine, ETContainer;


@interface ETTableLayout : ETLayout
{
	NSMutableDictionary *_propertyColumns;
	NSFont *_contentFont;
	NSEvent *_lastDragEvent;
	int _lastChildDropIndex;
}

- (NSArray *) displayedProperties;
- (void) setDisplayedProperties: (NSArray *)properties;
- (NSString *) displayNameForProperty: (NSString *)property;
- (void) setDisplayName: (NSString *)displayName forProperty: (NSString *)property;
- (BOOL) isEditableForProperty: (NSString *)property;
- (void) setEditable: (BOOL)flag forProperty: (NSString *)property;
- (id) styleForProperty: (NSString *)property;
- (void) setStyle: (id)style forProperty: (NSString *)property;

- (NSFont *) contentFont;
- (void) setContentFont: (NSFont *)aFont;

/* Widget Backend Access */

- (NSArray *) allTableColumns;
- (void) setAllTableColumns: (NSArray *)columns;
- (NSTableView *) tableView;

/* Subclassing */

- (NSTableColumn *) tableColumnWithIdentifierAndCreateIfAbsent: (NSString *)identifier;

// TODO: Moves this method into an NSTableColumn category
- (NSTableColumn *) _createTableColumnWithIdentifier: (NSString *)property;
- (NSEvent *) lastDragEvent;
- (void) setLastDragEvent: (NSEvent *)event;

@end
