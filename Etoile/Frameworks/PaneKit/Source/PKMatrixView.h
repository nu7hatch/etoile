/*
	PKMatrixView.h
 
	Matrix view enclosed in a scroll view (with pane displayed in a content subview)
 
	Copyright (C) 2005 Yen-Ju Chen, Quentin Mathe 
 
	Author:  Yen-Ju Chen
	Date:  December 2005
 
	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.
 
	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	Lesser General Public License for more details.
 
	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import <AppKit/AppKit.h>

@interface PKMatrixView: NSControl
{
	NSMatrix *matrix;
	NSScrollView *scrollView;
	NSView *contentView;
	int count;
}

- (id) initWithFrame: (NSRect) rect
       numberOfButtons: (int) count;

- (NSSize) frameSizeForContentSize: (NSSize) size;
- (void) addButtonCell: (NSButtonCell *) cell;
- (NSButtonCell *) selectedButtonCell;

/* The view below matrix */
- (NSView *) contentView;

@end
