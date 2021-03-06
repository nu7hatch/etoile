/*
   XFunctions.h for XWindowServerKit
   Copyright (c) 2006        Yen-Ju Chen
   All rights reserved.

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

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#import <X11/Xlib.h>

/* Get class and instance of a given window.
 * return NO if failed */
BOOL XWindowClassHint(Window window, NSString **wm_class, NSString **wm_instance);

/* Get the first icon from _NET_WM_ICON */
NSImage *XWindowIcon(Window window);

/* Get state of window, ex. IconicState */
unsigned long XWindowState(Window win);

/* Get _NET_WM_STATE, return count as number of properties */
Atom *XWindowNetStates(Window win, unsigned long *count);

/* Get group window. Return 0 if there is none */
Window XWindowGroupWindow(Window win);

/* Get the command path */
NSString* XWindowCommandPath(Window win);

/* Get title */
NSString *XWindowTitle(Window win);

/* Returns if the window is an icon window */
BOOL XWindowIsIcon(Window win);

/* Close a window (forcefully) */
void XWindowCloseWindow(Window win, BOOL forcefully);

/* Get GNUstep window level through x window system.
 * Return NO if it is not a GNUstep window. */
BOOL XGNUstepWindowLevel(Window win, int *level); 

/* Set specified window as active. 
   old is previous active window or None if unknown. */
void XWindowSetActiveWindow(Window win, Window old);

/* Return X window ID based on _NET_ACTIVE_WINDOW.
   Return None if none or fails. */
Window XWindowActiveWindow();

/* Return number of desktop of xwindow */
unsigned int XWindowDesktopOfWindow(Window win);

/* See whether it is in "showing desktop" mode. (_NET_SHOWING_DESKTOP) */
BOOL XWindowIsShowingDesktop();

/* Set _NET_SHOWING_DESKTOP */
void XWindowSetShowingDesktop(BOOL flag);

/* Freedesktop.org stuff */
NSString *XDGConfigHomePath();
NSString *XDGDataHomePath();
NSArray *XDGConfigDirectories();
NSArray *XDGDataDirectories();

