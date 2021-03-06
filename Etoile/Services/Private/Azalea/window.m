/* -*- indent-tabs-mode: nil; tab-width: 4; c-basic-offset: 4; -*-

   window.m for the Azalea window manager
   Copyright (c) 2006        Yen-Ju Chen

   window.c for the Openbox window manager
   Copyright (c) 2003        Ben Jansens

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   See the COPYING file for a copy of the GNU General Public License.
*/

#import "window.h"
#import "AZStacking.h"

NSMutableDictionary *window_map = nil;

void window_startup(BOOL reconfig)
{
    if (reconfig) return;
    window_map = [[NSMutableDictionary alloc] init];
}

void window_shutdown(BOOL reconfig)
{
    if (reconfig) return;

    DESTROY(window_map);
}

@implementation AZInternalWindow

- (Window) window { return window; }
- (void) set_window: (Window) w { window = w; }

- (Window_InternalType) windowType { return Window_Internal; }
- (Window) windowTop { return window; }
- (int) windowLayer { return OB_STACKING_LAYER_INTERNAL; }

@end

