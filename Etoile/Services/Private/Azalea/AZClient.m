/* -*- indent-tabs-mode: nil; tab-width: 4; c-basic-offset: 4; -*-
   
   AZClient.m for the Azalea window manager
   Copyright (c) 2006        Yen-Ju Chen

   client.c for the Openbox window manager
   Copyright (c) 2004        Mikael Magnusson
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

#import <AppKit/AppKit.h>
#import "AZClient.h"
#import "AZClient+GNUstep.h"
#import "AZDebug.h"
#import "AZScreen.h"
#import "AZClientManager.h"
#import "AZEventHandler.h"
#import "AZStartupHandler.h"
#import "AZFocusManager.h"
#import "prop.h"
#import "config.h"
#import "openbox.h"
#import "action.h"
#import "session.h"
#import "extensions.h"

#ifdef HAVE_UNISTD_H // For locahost name
#  include <unistd.h>
#endif



@interface AZClient (AZPrivate)
- (AZClientIcon *) iconRecursiveWithWidth: (int) w height: (int) h;
- (ObStackingLayer) calcStackingLayer;;
- (void) calcLayerRecursiveWithOriginal: (AZClient *)orig
	stackingLayer: (ObStackingLayer) l raised: (BOOL) raised;
- (void) setDesktopRecursive: (unsigned int) target
                        hide: (BOOL) donthide;
- (void) iconifyRecursive: (BOOL) iconic currentDesktop: (BOOL) curdesk;
- (void) getStartupId;
- (void) getArea;
- (void) getDesktop;
- (void) getState;
- (void) getLayer;
- (void) getShaped;
- (void) getMwmHints;
- (void) getGravity;
- (void) getClientMachine;
@end

@implementation AZClient

- (BOOL) shouldShow
{
    if (iconic)
        return NO;
    if ([self normal] && [[AZScreen defaultScreen] showingDesktop])
        return NO;
    if (desktop == [[AZScreen defaultScreen] desktop] || desktop == DESKTOP_ALL)
        return YES;
    
    return NO;
}

- (BOOL) normal
{
    return !(type == OB_CLIENT_TYPE_DESKTOP ||
             type == OB_CLIENT_TYPE_DOCK ||
             type == OB_CLIENT_TYPE_SPLASH);
}

- (void) moveToX: (int) x y: (int) y
{
  [self configureToCorner: OB_CORNER_TOPLEFT x: x y: y
	  width: area.width height: area.height user: YES final: YES];
}

- (void) resizeToWidth: (int) w height: (int) h
{
  [self configureToCorner: OB_CORNER_TOPLEFT x: area.x y: area.y
	  width: w height: h user: YES final: YES];
}

- (void) moveAndResizeToX: (int) x y: (int) y width: (int) w height: (int) h
{
  [self configureToCorner: OB_CORNER_TOPLEFT x: x y: y
	  width: w height: h user: YES final: YES];
}

- (void) configureToCorner: (ObCorner) anchor x: (int) x y: (int) y
		     width: (int) w height: (int) h
                      user: (BOOL) user final: (BOOL) final
{
  [self configureToCorner: anchor x: x y: y width: w height: h
	            user: user final: final forceReply: NO];
}

- (void) tryConfigureToCorner: (ObCorner) anchor
                     x: (int *) x y: (int *) y 
                     width: (int *) w height: (int *) h 
                     logicalW: (int *) logicalw logicalH: (int *) logicalh
                     user: (BOOL) user
{
    Rect desired_area = {*x, *y, *w, *h};

    /* make the frame recalculate its dimentions n shit without changing
       anything visible for real, this way the constraints below can work with
       the updated frame dimensions. */
    [frame adjustAreaWithMoved: YES resized: YES fake: YES];

    /* work within the prefered sizes given by the window.
	 * NOTE: this only apply to user resizing, not programminly resizing. */
    if ((!(*w == area.width && *h == area.height)) && user)
	{
        int basew, baseh, minw, minh;

        /* base size is substituted with min size if not specified */
        if (base_size.width || base_size.height) {
            basew = base_size.width;
            baseh = base_size.height;
        } else {
            basew = min_size.width;
            baseh = min_size.height;
        }
        /* min size is substituted with base size if not specified */
        if (min_size.width || min_size.height) {
            minw = min_size.width;
            minh = min_size.height;
        } else {
            minw = base_size.width;
            minh = base_size.height;
        }

        /* if this is a user-requested resize, then check against min/max
           sizes */

        /* smaller than min size or bigger than max size? */
        if (*w > max_size.width) *w = max_size.width;
        if (*w < minw) *w = minw;
        if (*h > max_size.height) *h = max_size.height;
        if (*h < minh) *h = minh;

        *w -= basew;
        *h -= baseh;

        /* keep to the increments */
        *w /= size_inc.width;
        *h /= size_inc.height;

        /* you cannot resize to nothing */
        if (basew + *w < 1) *w = 1 - basew;
        if (baseh + *h < 1) *h = 1 - baseh;
  
        /* save the logical size */
        *logicalw = size_inc.width > 1 ? *w : *w + basew;
        *logicalh = size_inc.height > 1 ? *h : *h + baseh;

        *w *= size_inc.width;
        *h *= size_inc.height;

        *w += basew;
        *h += baseh;

        /* adjust the height to match the width for the aspect ratios.
           for this, min size is not substituted for base size ever. */
        *w -= base_size.width;
        *h -= base_size.height;

        if (!fullscreen) {
            if (min_ratio)
                if (*h * min_ratio > *w) {
                    *h = (int)(*w / min_ratio);

                    /* you cannot resize to nothing */
                    if (*h < 1) {
                        *h = 1;
                        *w = (int)(*h * min_ratio);
                    }
                }
            if (max_ratio)
                if (*h * max_ratio < *w) {
                    *h = (int)(*w / max_ratio);

                    /* you cannot resize to nothing */
                    if (*h < 1) {
                        *h = 1;
                        *w = (int)(*h * min_ratio);
                    }
                }
        }

        *w += base_size.width;
        *h += base_size.height;
    }

    /* gets the frame's position */
    [frame clientGravityAtX: x y: y];

    /* these positions are frame positions, not client positions */

    /* set the size and position if fullscreen */
    AZScreen *screen = [AZScreen defaultScreen];
    if (fullscreen) {
        Rect *a;
        unsigned int i;

	i = [screen findMonitor: &desired_area];
	a = [screen physicalAreaOfMonitor: i];

        *x = a->x;
        *y = a->y;
        *w = a->width;
        *h = a->height;

        user = NO; /* ignore if the client can't be moved/resized when it
                      is entering fullscreen */
    } else if (max_horz || max_vert) {
        Rect *a;
        unsigned int i;

	i = [screen findMonitor: &desired_area];
	a = [screen areaOfDesktop: desktop monitor: i];

        /* set the size and position if maximized */
        if (max_horz) {
            *x = a->x;
            *w = a->width - [frame size].left - [frame size].right;
        }
        if (max_vert) {
            *y = a->y;
            *h = a->height - [frame size].top - [frame size].bottom;
        }

        /* maximizing is not allowed if the user can't move+resize the window
         */
    }

    /* gets the client's position */
    [frame frameGravityAtX: x y: y];

    /* these override the above states! if you cant move you can't move! */
    if (user) {
        if (!(functions & OB_CLIENT_FUNC_MOVE)) {
            *x = area.x;
            *y = area.y;
        }
        if (!(functions & OB_CLIENT_FUNC_RESIZE)) {
            *w = area.width;
            *h = area.height;
        }
    }

    if (*w <= 0) NSLog(@"Internal Error: width less than 0");
    if (*h <= 0) NSLog(@"Internal Error: height less than 0");

    switch (anchor) {
    case OB_CORNER_TOPLEFT:
        break;
    case OB_CORNER_TOPRIGHT:
        *x -= *w - area.width;
        break;
    case OB_CORNER_BOTTOMLEFT:
        *y -= *h - area.height;
        break;
    case OB_CORNER_BOTTOMRIGHT:
        *x -= *w - area.width;
        *y -= *h - area.height;
        break;
    }
}

- (void) configureToCorner: (ObCorner) anchor x: (int) x y: (int) y
                     width: (int) w height: (int) h
                      user: (BOOL) user final: (BOOL) final
                forceReply: (BOOL) force_reply;
{
    int oldw, oldh, oldrx, oldry;
    BOOL send_resize_client;
    BOOL moved = NO, resized = NO, rootmoved = NO;
    unsigned int fdecor = [frame decorations];
    BOOL fhorz = [frame max_horz];
    int logicalw, logicalh;

    /* find the new x, y, width, and height (and logical size) */
    [self tryConfigureToCorner: anchor x: &x y: &y width: &w height: &h
                      logicalW: &logicalw logicalH: &logicalh user: user];

    /* set the logical size if things changed */
    if (!(w == area.width && h == area.height))
        SIZE_SET(logical_size, logicalw, logicalh);

    /* figure out if we moved or resized or what */
    moved = x != area.x || y != area.y;
    resized = w != area.width || h != area.height;

    oldw = area.width;
    oldh = area.height;
    RECT_SET(area, x, y, w, h);

    /* for app-requested resizes, always resize if 'resized' is true.
       for user-requested ones, only resize if final is true, or when
       resizing in redraw mode */
    send_resize_client = ((!user && resized) ||
                          (user && (final ||
                                    (resized && config_resize_redraw))));

    /* if the client is enlarging, then resize the client before the frame */
    if (send_resize_client && user && (w > oldw || h > oldh))
        XResizeWindow(ob_display, window, MAX(w, oldw), MAX(h, oldh));

    /* find the frame's dimensions and move/resize it */
    if (decorations != fdecor || max_horz != fhorz)
        moved = resized = YES;

    if (moved || resized)
	[frame adjustAreaWithMoved: moved resized: resized fake: NO];

    /* find the client's position relative to the root window */
    oldrx = root_pos.x;
    oldry = root_pos.y;
    rootmoved = (oldrx != (signed)([frame area].x +
                                   [frame size].left -
                                   border_width) ||
                 oldry != (signed)([frame area].y +
                                   [frame size].top -
                                   border_width));

    if (force_reply || ((!user || (user && final)) && rootmoved))
    {
        XEvent event;
        POINT_SET(root_pos,
                  [frame area].x + [frame size].left -
                  border_width,
                  [frame area].y + [frame size].top -
                  border_width);

        event.type = ConfigureNotify;
        event.xconfigure.display = ob_display;
        event.xconfigure.event = window;
        event.xconfigure.window = window;

        /* root window real coords */
        event.xconfigure.x = root_pos.x;
        event.xconfigure.y = root_pos.y;
        event.xconfigure.width = w;
        event.xconfigure.height = h;
        event.xconfigure.border_width = 0;
        event.xconfigure.above = [frame plate];
        event.xconfigure.override_redirect = False;
        XSendEvent(event.xconfigure.display, event.xconfigure.window,
                   False, StructureNotifyMask, &event);
    }

    /* if the client is shrinking, then resize the frame before the client */
    if (send_resize_client && (!user || (w <= oldw || h <= oldh)))
        XResizeWindow(ob_display, window, w, h);

    XFlush(ob_display);
}


- (void) reconfigure
{
    /* by making this pass NO for user, we avoid the emacs event storm where
       every configurenotify causes an update in its normal hints, i think this
       is generally what we want anyways... */
  [self configureToCorner: OB_CORNER_TOPLEFT x: area.x y: area.y
	  width: area.width height: area.height user: NO final: YES];
}

- (void) moveOnScreen: (BOOL) rude
{
    int x = area.x;
    int y = area.y;
    if ([self findOnScreenAtX: &x y: &y
		        width: [frame area].width height: [frame area].height
			rude: rude]) 
    {
      [self moveToX: x y: y];
    }
}

- (BOOL) findOnScreenAtX: (int *) x y: (int *) y
                   width: (int) w height: (int) h rude: (BOOL) rude
{
    Rect *a;
    int ox = *x, oy = *y;
    AZScreen *screen = [AZScreen defaultScreen];

    [frame clientGravityAtX: x y: y]; /* get where the frame would be */

    /* XXX watch for xinerama dead areas */
    /* This makes sure windows aren't entirely outside of the screen so you
       can't see them at all.
       It makes sure 10% of the window is on the screen at least. At don't let
       it move itself off the top of the screen, which would hide the titlebar
       on you. (The user can still do this if they want too, it's only limiting
       the application.
    */

    if ([self normal]) {
        a = [screen areaOfDesktop: desktop];
        if (!strut.right &&
            *x + [frame area].width/10 >= a->x + a->width - 1)
            *x = a->x + a->width - [frame area].width/10;
        if (!strut.bottom &&
            *y + [frame area].height/10 >= a->y + a->height - 1)
            *y = a->y + a->height - [frame area].height/10;
        if (!strut.left && *x + [frame area].width*9/10 - 1 < a->x)
            *x = a->x - [frame area].width*9/10;
        if (!strut.top && *y + [frame area].height*9/10 - 1 < a->y)
            *y = a->y - [frame area].width*9/10;
    }
    /* Azalea: for GNUstep menu, it will reposition itself to be inside the
       screen. If we force it here, it will not display properly. 
       So we avoid reposition GNUstep menu here. Although it may not be
       the best solution and may have some side effect.
       FIXME: this is a temporary fix, though. */
    if ([self isGNUstepMenuWindowLevel]) {
      rude = NO;
    }

    /* This here doesn't let windows even a pixel outside the screen,
     * when called from client_manage, programs placing themselves are
     * forced completely onscreen, while things like
     * xterm -geometry resolution-width/2 will work fine. Trying to
     * place it completely offscreen will be handled in the above code.
     * Sorry for this confused comment, i am tired. */
    if (rude) {
        /* avoid the xinerama monitor divide while we're at it,
         * remember to fix the placement stuff to avoid it also and
         * then remove this XXX */
	a = [screen areaOfDesktop: [self desktop]
 			  monitor: [self monitor]];
        /* dont let windows map into the strut unless they
           are bigger than the available area */
        if (w <= a->width) {
            if (!strut.left && *x < a->x) *x = a->x;
            if (!strut.right && *x + w > a->x + a->width)
                *x = a->x + a->width - w;
        }
        if (h <= a->height) {
            if (!strut.top && *y < a->y) *y = a->y;
            if (!strut.bottom && *y + h > a->y + a->height)
                *y = a->y + a->height - h;
        }
    }

    [frame frameGravityAtX: x y: y]; /* get where the client should be */
    return ox != *x || oy != *y;
}

- (void) fullscreen: (BOOL) fs
{
    int x, y, w, h;

    if (!(functions & OB_CLIENT_FUNC_FULLSCREEN) || /* can't */
        fullscreen == fs) return;                   /* already done */

    fullscreen = fs;
    [self changeState]; /* change the state hints on the client */
    [self calcLayer];   /* and adjust out layer/stacking */

    if (fs) {
        pre_fullscreen_area = area;
        /* if the window is maximized, its area isn't all that meaningful.
           save it's premax area instead. */
        if (max_horz) {
            pre_fullscreen_area.x = pre_max_area.x;
            pre_fullscreen_area.width = pre_max_area.width;
        }
        if (max_vert) {
            pre_fullscreen_area.y = pre_max_area.y;
            pre_fullscreen_area.height = pre_max_area.height;
        }

        /* these are not actually used cuz client_configure will set them
           as appropriate when the window is fullscreened */
        x = y = w = h = 0;
    } else {
        Rect *a;

        if (pre_fullscreen_area.width > 0 &&
            pre_fullscreen_area.height > 0)
        {
            x = pre_fullscreen_area.x;
            y = pre_fullscreen_area.y;
            w = pre_fullscreen_area.width;
            h = pre_fullscreen_area.height;
            RECT_SET(pre_fullscreen_area, 0, 0, 0, 0);
        } else {
            /* pick some fallbacks... */
            a = [[AZScreen defaultScreen] areaOfDesktop: desktop monitor: 0];
            x = a->x + a->width / 4;
            y = a->y + a->height / 4;
            w = a->width / 2;
            h = a->height / 2;
        }
    }

    [self setupDecorAndFunctions];

    [self moveAndResizeToX: x y: y width: w height: h];

    /* try focus us when we go into fullscreen mode */
    [self focus];
}

- (void) iconify: (BOOL) _iconic currentDesktop: (BOOL) curdesk
{
    AZClient *client = [self searchTopParent];
    [client iconifyRecursive: _iconic currentDesktop: curdesk];
}

- (void) maximize: (BOOL) max direction: (int) dir
{
    int x, y, w, h;
     
    NSAssert((dir == 0 || dir == 1 || dir == 2), @"Wrong direction");
    if (!(functions & OB_CLIENT_FUNC_MAXIMIZE)) return; /* can't */

    /* check if already done */
    if (max) {
        if (dir == 0 && max_horz && max_vert) return;
        if (dir == 1 && max_horz) return;
        if (dir == 2 && max_vert) return;
    } else {
        if (dir == 0 && !max_horz && !max_vert) return;
        if (dir == 1 && !max_horz) return;
        if (dir == 2 && !max_vert) return;
    }

    /* we just tell it to configure in the same place and client_configure
       worries about filling the screen with the window */
    x = area.x;
    y = area.y;
    w = area.width;
    h = area.height;

    if (max) {
        if ((dir == 0 || dir == 1) && !max_horz) { /* horz */
            RECT_SET(pre_max_area,
                     area.x, pre_max_area.y,
                     area.width, pre_max_area.height);
	}
        if ((dir == 0 || dir == 2) && !max_vert) { /* vert */
            RECT_SET(pre_max_area,
                     pre_max_area.x, area.y,
                     pre_max_area.width, area.height);
        }
    } else {
        Rect *a;

	a = [[AZScreen defaultScreen] areaOfDesktop: desktop
		 monitor: 0];
        if ((dir == 0 || dir == 1) && max_horz) { /* horz */
            if (pre_max_area.width > 0) {
                x = pre_max_area.x;
                w = pre_max_area.width;

                RECT_SET(pre_max_area, 0, pre_max_area.y,
                         0, pre_max_area.height);
            } else {
                /* pick some fallbacks... */
                x = a->x + a->width / 4;
                w = a->width / 2;
            }
        }
        if ((dir == 0 || dir == 2) && max_vert) { /* vert */
            if (pre_max_area.height > 0) {
                y = pre_max_area.y;
                h = pre_max_area.height;

                RECT_SET(pre_max_area, pre_max_area.x, 0,
                         pre_max_area.width, 0);
            } else {
                /* pick some fallbacks... */
                y = a->y + a->height / 4;
                h = a->height / 2;
            }
        }
    }

    if (dir == 0 || dir == 1) /* horz */
        max_horz = max;
    if (dir == 0 || dir == 2) /* vert */
        max_vert = max;

    [self changeState]; /* change the state hints on the client */

    [self setupDecorAndFunctions];

    [self moveAndResizeToX: x y: y width: w height: h];
}

- (void) shade: (BOOL) shade
{
    if ((!(functions & OB_CLIENT_FUNC_SHADE) && shade) || /* can't shade */
        shaded == shade) return;     /* already done */

    shaded = shade;
    [self changeState];
    [self changeWMState];
    /* resize the frame to just the titlebar */
    [frame adjustAreaWithMoved: NO resized: NO fake: NO];
}

- (void) close
{
    XEvent ce;

    if (!(functions & OB_CLIENT_FUNC_CLOSE)) return;

    /* in the case that the client provides no means to requesting that it
       close, we just kill it */
    if (!delete_window)
	[self kill];
    
    /*
      XXX: itd be cool to do timeouts and shit here for killing the client's
      process off
      like... if the window is around after 5 seconds, then the close button
      turns a nice red, and if this function is called again, the client is
      explicitly killed.
    */

    ce.xclient.type = ClientMessage;
    ce.xclient.message_type =  prop_atoms.wm_protocols;
    ce.xclient.display = ob_display;
    ce.xclient.window = window;
    ce.xclient.format = 32;
    ce.xclient.data.l[0] = prop_atoms.wm_delete_window;
    ce.xclient.data.l[1] = event_curtime;
    ce.xclient.data.l[2] = 0l;
    ce.xclient.data.l[3] = 0l;
    ce.xclient.data.l[4] = 0l;
    XSendEvent(ob_display, window, NO, NoEventMask, &ce);
}

- (void) kill
{
    XKillClient(ob_display, window);
}

- (void) hilite: (BOOL) flag
{
   if (demands_attention == flag) 
       return; /* no change */

   /* don't allow focused windows to hilite */
   demands_attention = (flag && ![self focused]);
   if (demands_attention)
      [[self frame] flashStart];
   else
      [[self frame] flashStop];
   [self changeState];
}

- (void) setDesktop: (unsigned int) target hide: (BOOL) donthide
{
  AZClient *client = [self searchTopParent];
  [client setDesktopRecursive: target hide: donthide];
}

- (BOOL) validate
{
    XEvent e; 

    XSync(ob_display, NO); /* get all events on the server */

    if (XCheckTypedWindowEvent(ob_display, window, DestroyNotify, &e) ||
        XCheckTypedWindowEvent(ob_display, window, UnmapNotify, &e)) {
        XPutBackEvent(ob_display, &e);
        return NO;
    }

    return YES;
}

- (BOOL) focused
{
    return (self == [[AZFocusManager defaultManager] focus_client]);
}

- (void) setWmState: (long) state
{
    if (state == wmstate) return; /* no change */
  
    switch (state) {
    case IconicState:
	[self iconify: YES currentDesktop: YES];
        break;
    case NormalState:
	[self iconify: NO currentDesktop: YES];
        break;
    }
}

- (void) setState: (Atom) action data1: (long) data1 data2: (long) data2
{
    BOOL _shaded = shaded;
    BOOL _fullscreen = fullscreen;
    BOOL _undecorated = undecorated;
    BOOL _max_horz = max_horz;
    BOOL _max_vert = max_vert;
    BOOL _modal = modal;
    BOOL _iconic = iconic;
    BOOL _demands_attention = demands_attention;
    int i;

    if (!(action == prop_atoms.net_wm_state_add ||
          action == prop_atoms.net_wm_state_remove ||
          action == prop_atoms.net_wm_state_toggle))
        /* an invalid action was passed to the client message, ignore it */
        return; 

    for (i = 0; i < 2; ++i) {
        Atom state = i == 0 ? data1 : data2;
    
        if (!state) continue;

        /* if toggling, then pick whether we're adding or removing */
        if (action == prop_atoms.net_wm_state_toggle) {
            if (state == prop_atoms.net_wm_state_modal)
                action = _modal ? prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_maximized_vert)
                action = max_vert ? prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_maximized_horz)
                action = max_horz ? prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_shaded)
                action = _shaded ? prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_skip_taskbar)
                action = skip_taskbar ?
                    prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_skip_pager)
                action = skip_pager ?
                    prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_hidden)
                action = iconic ?
                    prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_fullscreen)
                action = _fullscreen ?
                    prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_above)
                action = above ? prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_below)
                action = below ? prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.net_wm_state_demands_attention)
                action = demands_attention ?
                    prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
            else if (state == prop_atoms.ob_wm_state_undecorated)
                action = _undecorated ? prop_atoms.net_wm_state_remove :
                    prop_atoms.net_wm_state_add;
        }
    
        if (action == prop_atoms.net_wm_state_add) {
            if (state == prop_atoms.net_wm_state_modal) {
                _modal = YES;
            } else if (state == prop_atoms.net_wm_state_maximized_vert) {
                _max_vert = YES;
            } else if (state == prop_atoms.net_wm_state_maximized_horz) {
                _max_horz = YES;
            } else if (state == prop_atoms.net_wm_state_shaded) {
                _shaded = YES;
            } else if (state == prop_atoms.net_wm_state_skip_taskbar) {
                skip_taskbar = YES;
            } else if (state == prop_atoms.net_wm_state_skip_pager) {
                skip_pager = YES;
            } else if (state == prop_atoms.net_wm_state_hidden) {
                _iconic = YES;
            } else if (state == prop_atoms.net_wm_state_fullscreen) {
                _fullscreen = YES;
            } else if (state == prop_atoms.net_wm_state_above) {
                above = YES;
                below = NO;
            } else if (state == prop_atoms.net_wm_state_below) {
                above = NO;
                below = YES;
            } else if (state == prop_atoms.net_wm_state_demands_attention) {
                _demands_attention = YES;
            } else if (state == prop_atoms.ob_wm_state_undecorated) {
                _undecorated = YES;
            }

        } else { /* action == prop_atoms.net_wm_state_remove */
            if (state == prop_atoms.net_wm_state_modal) {
                _modal = NO;
            } else if (state == prop_atoms.net_wm_state_maximized_vert) {
                _max_vert = NO;
            } else if (state == prop_atoms.net_wm_state_maximized_horz) {
                _max_horz = NO;
            } else if (state == prop_atoms.net_wm_state_shaded) {
                _shaded = NO;
            } else if (state == prop_atoms.net_wm_state_skip_taskbar) {
                skip_taskbar = NO;
            } else if (state == prop_atoms.net_wm_state_skip_pager) {
                skip_pager = NO;
            } else if (state == prop_atoms.net_wm_state_hidden) {
                _iconic = NO;
            } else if (state == prop_atoms.net_wm_state_fullscreen) {
                _fullscreen = NO;
            } else if (state == prop_atoms.net_wm_state_above) {
                above = NO;
            } else if (state == prop_atoms.net_wm_state_below) {
                below = NO;
            } else if (state == prop_atoms.net_wm_state_demands_attention) {
                _demands_attention = NO;
            } else if (state == prop_atoms.ob_wm_state_undecorated) {
                _undecorated = NO;
            }
        }
    }
    if (_max_horz != max_horz || _max_vert != max_vert) {
        if (_max_horz != max_horz && _max_vert != max_vert) {
            /* toggling both */
            if (_max_horz == _max_vert) { /* both going the same way */
		[self maximize: _max_horz direction: 0];
            } else {
		[self maximize: _max_horz direction: 1];
		[self maximize: _max_vert direction: 2];
            }
        } else {
            /* toggling one */
            if (_max_horz != max_horz)
		[self maximize: _max_horz direction: 1];
            else
		[self maximize: _max_vert direction: 2];
        }
    }
    /* change fullscreen state before shading, as it will affect if the window
       can shade or not */
    if (_fullscreen != fullscreen)
	[self fullscreen: _fullscreen];
    if (_shaded != shaded)
	[self shade: _shaded];
    if (_undecorated != undecorated)
        [self setUndecorated: _undecorated];
    if (_modal != modal) {
        modal = _modal;
        /* when a window changes modality, then its stacking order with its
           transients needs to change */
	[self raise];
    }
    if (_iconic != iconic)
	[self iconify: _iconic currentDesktop: NO];

    if (_demands_attention != demands_attention)
        [self hilite: _demands_attention];

    [self changeState]; /* change the hint to reflect these changes */
}

- (AZClient *) focusTarget
{
    AZClient *child = nil;
     
    child = [self searchModalChild];
    if (child) return child;
    return self;
}

- (BOOL) canFocus
{
    XEvent ev;

    /* choose the correct target */
    AZClient *oself = [self focusTarget];

    if (![[oself frame] visible])
        return NO;

    if (!([oself can_focus] || [oself focus_notify]))
        return NO;

    /* do a check to see if the window has already been unmapped or destroyed
       do this intelligently while watching out for unmaps we've generated
       (ignore_unmaps > 0) */
    if (XCheckTypedWindowEvent(ob_display, [oself window],
                               DestroyNotify, &ev)) {
        XPutBackEvent(ob_display, &ev);
        return NO;
    }
    while (XCheckTypedWindowEvent(ob_display, [oself window],
                                  UnmapNotify, &ev)) {
        if ([oself ignore_unmaps]) {
            [oself set_ignore_unmaps: [oself ignore_unmaps]-1];
        } else {
            XPutBackEvent(ob_display, &ev);
            return NO;
        }
    }

    return YES;
}

- (BOOL) focus
{
    /* choose the correct target */
    AZClient *oself = [self focusTarget];

    if (![oself canFocus]) {
        if (![[oself frame] visible]) {
            /* update the focus lists */
	    [[AZFocusManager defaultManager] focusOrderToTop: oself];
        }
        return NO;
    }

    if ([oself can_focus]) {
        /* This can cause a BadMatch error with CurrentTime, or if an app
           passed in a bad time for _NET_WM_ACTIVE_WINDOW. */
        AZXErrorSetIgnore(YES);
        XSetInputFocus(ob_display, [oself window], RevertToPointerRoot,
                       event_curtime);
        AZXErrorSetIgnore(NO);
    }

    if ([oself focus_notify]) {
        XEvent ce;
        ce.xclient.type = ClientMessage;
        ce.xclient.message_type = prop_atoms.wm_protocols;
        ce.xclient.display = ob_display;
        ce.xclient.window = [oself window];
        ce.xclient.format = 32;
        ce.xclient.data.l[0] = prop_atoms.wm_take_focus;
        ce.xclient.data.l[1] = event_curtime;
        ce.xclient.data.l[2] = 0l;
        ce.xclient.data.l[3] = 0l;
        ce.xclient.data.l[4] = 0l;
        XSendEvent(ob_display, [oself window], NO, NoEventMask, &ce);
    }

	NSDebugLLog(@"Focus", 
	            @"%sively focusing %lx at %d\n",
				(oself->can_focus ? "act" : "pass"),
				oself->window, (int) event_curtime);

    /* Cause the FocusIn to come back to us. Important for desktop switches,
       since otherwise we'll have no FocusIn on the queue and send it off to
       the focus_backup. */
    XSync(ob_display, NO);
    return YES;
}

- (void) activateHere: (BOOL) here user: (BOOL) user 
{
    AZFocusManager *fManager = [AZFocusManager defaultManager];
    unsigned int last_time = [fManager focus_client] ? [[fManager focus_client] user_time] : CurrentTime;
    AZScreen *screen = [AZScreen defaultScreen];
    /* XXX do some stuff here if user is false to determine if we really want
       to activate it or not (a parent or group member is currently
       active)?
    */
    if (!user && event_curtime && last_time &&
        !event_time_after(event_curtime, last_time))
    {
      [self hilite: YES];
    }
    else 
    {
        if ([self normal] && [screen showingDesktop])
	  [screen showDesktop: NO];
        if (iconic)
	  [self iconify: NO currentDesktop: here];
        if (desktop != DESKTOP_ALL &&
            desktop != [screen desktop]) 
	{
            if (here)
	      [self setDesktop: [screen desktop] hide: NO];
            else
	      [screen setDesktop: desktop];
        } else if (![frame visible])
            /* if its not visible for other reasons, then don't mess
               with it */
            return;
        if (shaded)
 	  [self shade: NO];

        [self focus];

        /* we do this an action here. this is rather important. this is because
           we want the results from the focus change to take place BEFORE we go
         about raising the window. when a fullscreen window loses focus, we need
           this or else the raise wont be able to raise above the to-lose-focus
           fullscreen window. */
        [self raise];
    }
}

- (void) calcLayer
{
    AZClient *orig = nil, *oself = self;
    NSArray *it = nil;

    orig = oself;
#if 0 // Statement below may not be correct anymore
    /* I do not fully understand why I need to treate GNUstep specially.
       If I don't, Azalea will complain in [AZStacking doRestack:...]
       where 'index == NSNotFound' and crashes most of time.
       My take is that for regular X-window, transient window has the same
       level as their parent window. But for GNUstep application,
       transient window has its own level (floating panel, menu, etc).
       If we set GNUstep window the same level as their parent,
       which is probably the main window, it is actually the wrong behavior.
       Although it does not explain why AZStacking complains and crashes,
       it behaves well.
       Another reason I can think about is that since we do not modify
       window level based on transient relationship,
       it is consistent with GNUstep, therefore, bug-free.
       For debug purpose, this happens between r1649 to r1650,
       or more specifically, in [AZClient calcLayer]. */
    if ([self isGNUstep])
    {
	layer = [self calcStackingLayer];
	return;
    }
#endif
    /* transients take on the layer of their parents */
    it = [oself searchAllTopParents];
    int i;
    for (i = 0; i < [it count]; i++)
    {
      [[it objectAtIndex: i]  calcLayerRecursiveWithOriginal: orig
 	                      stackingLayer: 0 raised: NO];
    }
}

- (void) raise
{
    action_run_string(@"Raise", self, CurrentTime);
}

- (void) lower
{
    action_run_string(@"Lower", self, CurrentTime);
}

- (void) updateTransientFor
{
    Window t = None;
    AZClient *target = nil;

    if (XGetTransientForHint(ob_display, window, &t)) {
        transient = YES;
        if (t != window) { /* cant be transient to itoself! */
	    target = (AZClient *)[window_map objectForKey: [NSNumber numberWithInt: t]];
            /* if this happens then we need to check for it*/
            NSAssert((target != self), @"target is self");
            if (target && !WINDOW_IS_CLIENT(target)) {
                /* this can happen when a dialog is a child of
                   a dockapp, for example */
                target = nil;
            }

            /* THIS IS SO ANNOYING ! ! ! ! Let me explain.... have a seat..

               Setting the transient_for to Root is actually illegal, however
               applications from time have done this to specify transient for
               their group.

               Now you can do that by being a TYPE_DIALOG and not setting
               the transient_for hint at all on your window. But people still
               use Root, and Kwin is very strange in this regard.

               KWin 3.0 will not consider windows with transient_for set to
               Root as transient for their group *UNLESS* they are also modal.
               In that case, it will make them transient for the group. This
               leads to all sorts of weird behavior from KDE apps which are
               only tested in KWin. I'd like to follow their behavior just to
               make this work right with KDE stuff, but that seems wrong.
            */
            if (!target && group) {
                /* not transient to a client, see if it is transient for a
                   group */
                if (t == RootWindow(ob_display, ob_screen))
                {
                    /* window is a transient for its group! */
                    target = OB_TRAN_GROUP;
                }
            }
        }
    } else if (group) {
        if (type == OB_CLIENT_TYPE_DIALOG ||
            type == OB_CLIENT_TYPE_TOOLBAR ||
            type == OB_CLIENT_TYPE_MENU ||
            type == OB_CLIENT_TYPE_UTILITY)
        {
            transient = YES;
            target = OB_TRAN_GROUP;
        }
    } else
        transient = NO;

    /* if anything has changed... */
    if (target != transient_for) {
        if (transient_for == OB_TRAN_GROUP) { /* transient of group */
            /* remove from old parents */
	    int i, count = [[group members] count];
	    for (i = 0; i < count; i++) {
	      AZClient *c = [group memberAtIndex: i];
              if (c != self && ![c transient_for])
		[c removeTransient: self];
            }
        } else if (transient_for != nil) { /* transient of window */
            /* remove from old parent */
	    [transient_for removeTransient: self];
        }
        transient_for = target;
        if (transient_for == OB_TRAN_GROUP) { /* transient of group */
            /* add to new parents */
	    int i, count = [[group members] count];
	    for (i = 0; i < count; i++) {
	      AZClient *c = [group memberAtIndex: i];
              if (c != self && ![c transient_for])
		    [c addTransient: self];
            }

            /* remove all transients which are in the group, that causes
               circlular pointer hell of doom */
	    count = [[group members] count];
	    for (i = 0; i < count; i++) {
	      AZClient *data = [group memberAtIndex: i];
	      [transients removeObject: data];
            }
        } else if (transient_for != nil) { /* transient of window */
            /* add to new parent */
	    [transient_for addTransient: self];
        }
    }
}

- (void) updateProtocols
{
    unsigned long *proto;
    unsigned int num_return, i;

    focus_notify = NO;
    delete_window = NO;

    if (PROP_GETA32(window, wm_protocols, atom, &proto, &num_return)) {
        for (i = 0; i < num_return; ++i) {
            if (proto[i] == prop_atoms.wm_delete_window) {
                /* this means we can request the window to close */
		delete_window = YES;
            } else if (proto[i] == prop_atoms.wm_take_focus)
                /* if this protocol is requested, then the window will be
                   notified whenever we want it to receive focus */
		focus_notify = YES;
        }
        free(proto);
    }
}

- (void) updateNormalHints
{
    XSizeHints size;
    long ret;
    int oldgravity = gravity;

    /* defaults */
    min_ratio = 0.0f;
    max_ratio = 0.0f;
    SIZE_SET(size_inc, 1, 1);
    SIZE_SET(base_size, 0, 0);
    SIZE_SET(min_size, 0, 0);
    SIZE_SET(max_size, INT_MAX, INT_MAX);

    /* get the hints from the window */
    if (XGetWMNormalHints(ob_display, window, &size, &ret)) {
        /* normal windows can't request placement! har har
        if (![self normal])
        */
        positioned = (size.flags & (PPosition|USPosition));

        if (size.flags & PWinGravity) {
            gravity = size.win_gravity;
      
            /* if the client has a frame, i.e. has already been mapped and
               is changing its gravity */
            if (frame && gravity != oldgravity) {
                /* move our idea of the client's position based on its new
                   gravity */
		area.x = [frame area].x;
		area.y = [frame area].y;
		[frame frameGravityAtX: &(area.x) y: &(area.y)];
            }
        }

        if (size.flags & PAspect) {
            if (size.min_aspect.y)
                min_ratio =
                    (float) size.min_aspect.x / size.min_aspect.y;
            if (size.max_aspect.y)
                max_ratio =
                    (float) size.max_aspect.x / size.max_aspect.y;
        }

        if (size.flags & PMinSize)
	{
            SIZE_SET(min_size, size.min_width, size.min_height);
	}
    
        if (size.flags & PMaxSize)
	{
            SIZE_SET(max_size, size.max_width, size.max_height);
	}
    
        if (size.flags & PBaseSize)
	{
            SIZE_SET(base_size, size.base_width, size.base_height);
	}
    
        if (size.flags & PResizeInc && size.width_inc && size.height_inc)
	{
            SIZE_SET(size_inc, size.width_inc, size.height_inc);
	}
    }
}

- (void) updateWmhints
{
    XWMHints *hints;

    /* assume a window takes input if it doesnt specify */
    can_focus = YES;
  
    if ((hints = XGetWMHints(ob_display, window)) != NULL) {
        if (hints->flags & InputHint)
	    can_focus = hints->input;

        /* only do this when first managing the window *AND* when we aren't
           starting up! */
        if (ob_state() != OB_STATE_STARTING && frame == nil)
            if (hints->flags & StateHint)
                iconic = (hints->initial_state == IconicState);

        if (!(hints->flags & WindowGroupHint))
            hints->window_group = None;

        /* did the group state change? */
        if (hints->window_group !=
            (group ? [group leader] : None)) {
            /* remove from the old group if there was one */
            if (group != nil) {
                /* remove transients of the group */
	        int i, count = [[group members] count];
		for (i = 0; i < count; i++) {
		  AZClient *data = [group memberAtIndex: i];
		  [transients removeObject: data];
		}

                /* remove myoself from parents in the group */
                if (transient_for == OB_TRAN_GROUP) {
		    count = [[group members] count];
		    for (i = 0; i < count; i++)
		    {
                        AZClient *c = [group memberAtIndex: i];

                        if (c != self && ![c transient_for])
			   [c removeTransient: self];
                    }
                }

		[[AZGroupManager defaultManager] removeClient: self fromGroup: group];
		group = nil;
            }
            if (hints->window_group != None) {
                group = [[AZGroupManager defaultManager] addWindow: hints->window_group withClient: self];

                /* i can only have transients from the group if i am not
                   transient myoself */
                if (!transient_for) {
                    /* add other transients of the group that are already
                       set up */
	            int i, count = [[group members] count];
		    for (i = 0; i < count; i++) {
		      AZClient *c = [group memberAtIndex: i];
                      if (c != self && [c transient_for] == OB_TRAN_GROUP)
			[transients addObject: c];
                    }
                }
            }

            /* because the oself->transient flag wont change from this call,
               we don't need to update the window's type and such, only its
               transient_for, and the transients lists of other windows in
               the group may be affected */
	    [self updateTransientFor];
        }

        /* the WM_HINTS can contain an icon */
	[self updateIcons];

        XFree(hints);
    }
}

- (void) updateTitle
{
    NSString *s = nil;
    NSString *visible = nil;
     
    /* try netwm */
    if (PROP_GETS(window, net_wm_name, utf8, &s)) {
      ASSIGNCOPY(title, s);
    } else if (PROP_GETS(window, wm_name, utf8, &s)) {
      /* try old x with utf */
      ASSIGNCOPY(title, s);
    } else if (PROP_GETS(window, wm_name, locale, &s)) {
      /* try old x stuff */
      ASSIGNCOPY(title, s);
    } else {
      /*
        GNOME alert windows are not given titles:
        http://developer.gnome.org/projects/gup/hig/draft_hig_new/windows-alert.html
       */
      if (transient) {
	  ASSIGN(title, [NSString string]);
      } else {
	  ASSIGN(title, [NSString stringWithCString: "Unnamed Window"]);
      }
    }

    if (client_machine) {
	ASSIGN(visible, ([NSString stringWithFormat: @"%@ (%@)", title, client_machine]));
    } else
	ASSIGNCOPY(visible, title);

    PROP_SETS(window, net_wm_visible_name, (char*)[visible UTF8String]);
    ASSIGNCOPY(title, visible);

    if (frame)
	[frame adjustTitle];

    /* update the icon title */
    s = nil;
    DESTROY(icon_title);

    /* try netwm */
    if (PROP_GETS(window, net_wm_icon_name, utf8, &s)) {
      ASSIGNCOPY(icon_title, s);
    } else if (PROP_GETS(window, wm_icon_name, utf8, &s)) {
      /* try old x stuff with utf8*/
      ASSIGNCOPY(icon_title, s);
    } else if (PROP_GETS(window, wm_icon_name, locale, &s)) {
      /* try old x stuff */
      ASSIGNCOPY(icon_title, s);
    } else {
      ASSIGNCOPY(icon_title, title);
    }

    PROP_SETS(window, net_wm_visible_icon_name, (char*)[icon_title UTF8String]);
}

- (void) updateClass
{
    NSArray *data;
    NSString *s = nil;

    DESTROY(name);
    DESTROY(class);
    DESTROY(role);

    if (PROP_GETSS(window, wm_class, locale, &data)) {
        if ([data count] > 0) {
	    ASSIGNCOPY(name, [data objectAtIndex: 0]);
            if ([data count] > 1)
		ASSIGNCOPY(class, [data objectAtIndex: 1]);
        }
    }

    if (PROP_GETS(window, wm_window_role, locale, &s)) {
	ASSIGNCOPY(role, s);
    }

    if (name == nil) ASSIGN(name, [NSString string]);
    if (class == nil) ASSIGN(class, [NSString string]);
    if (role == nil) ASSIGN(role, [NSString string]);
}

- (void) updateStrut
{
    unsigned int num;
    unsigned long *data;
    BOOL got = NO;
    StrutPartial _strut = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; 

    if (PROP_GETA32(window, net_wm_strut_partial, cardinal,
                    &data, &num)) {
        if (num == 12) {
            got = YES;
            STRUT_PARTIAL_SET(_strut,
                              data[0], data[2], data[1], data[3],
                              data[4], data[5], data[8], data[9],
                              data[6], data[7], data[10], data[11]);
        }
        free(data);
    }

    if (!got &&
        PROP_GETA32(window, net_wm_strut, cardinal, &data, &num)) {
        if (num == 4) {
            const Rect *a;

            got = YES;

            /* use the screen's width/height */
            a = [[AZScreen defaultScreen] physicalArea];

            STRUT_PARTIAL_SET(_strut,
                              data[0], data[2], data[1], data[3],
                              a->y, a->y + a->height - 1,
                              a->x, a->x + a->width - 1,
                              a->y, a->y + a->height - 1,
                              a->x, a->x + a->width - 1);
        }
        free(data);
    }   

    if (!STRUT_EQUAL(_strut, strut)) {
        strut = _strut;

        /* updating here is pointless while we're being mapped cuz we're not in
           the client list yet */
        if (frame)
	{
	    [[AZScreen defaultScreen] updateAreas];
	}
    }
}

- (void) updateIcons;
{
	unsigned int num;
	unsigned long *data;
	unsigned int w, h, i, j;

	[self removeAllIcons];

	if (PROP_GETA32(window, net_wm_icon, cardinal, &data, &num)) 
	{
		int nicons = 0;
		/* figure out how many valid icons are in here */
		i = 0;
		while (num - i > 2) 
		{
			w = data[i++];
			h = data[i++];
			i += w * h;
			if (i > num || w*h == 0) 
				break;
			++nicons;
		}

		/* store the icons */
		i = 0;
		for (j = 0; j < nicons; ++j) 
		{
			unsigned int x, y, t;

			AZClientIcon *icon = AUTORELEASE([[AZClientIcon alloc] init]);
			w = data[i++];
			h = data[i++];
			[icon setWidth: w];
			[icon setHeight: h];

			if (w*h == 0) 
				continue;

			RrPixel32 *temp = calloc(sizeof(RrPixel32), w * h);
			for (x = 0, y = 0, t = 0; t < w * h; ++t, ++x, ++i) 
			{
				if (x >= w) 
				{
					x = 0;
					++y;
				}
				temp[t] = (((data[i] >> 24) & 0xff) << RrDefaultAlphaOffset) +
				            (((data[i] >> 16) & 0xff) << RrDefaultRedOffset) +
				            (((data[i] >> 8) & 0xff) << RrDefaultGreenOffset) +
				            (((data[i] >> 0) & 0xff) << RrDefaultBlueOffset);
			}
			NSAssert(i <= num, @"Out of range");
			[icon setData: temp];
			[self addIcon: icon];
		}

		free(data);
	}
	else 
	{
		XWMHints *hints;

		if ((hints = XGetWMHints(ob_display, window))) 
		{
			if (hints->flags & IconPixmapHint) 
			{
				int _w, _h;
				RrPixel32 *_temp;
				AZXErrorSetIgnore(YES);
				if (!RrPixmapToRGBA(ob_rr_inst,
                                    hints->icon_pixmap,
                                    (hints->flags & IconMaskHint ?
                                     hints->icon_mask : None),
                                    &_w, &_h, &_temp))
				{
				}
				else // success
				{
					AZClientIcon *icon = [[AZClientIcon alloc] init];
					[icon setWidth: _w];
					[icon setHeight: _h];
					[icon setData: _temp];
					[self addIcon: icon];
					DESTROY(icon);
				}
				AZXErrorSetIgnore(NO);
			}
			XFree(hints);
		}
	}

	if (frame)
		[frame adjustIcon];
}

- (void) updateUserTime
{
    unsigned long time;

    if (PROP_GET32([self window], net_wm_user_time, cardinal, &time)) {
        /* we set this every time, not just when it grows, because in practice
           sometimes time goes backwards! (ntpdate.. yay....) so.. if it goes
           backward we don't want all windows to stop focusing. we'll just
           assume noone is setting times older than the last one, cuz that
           would be pretty stupid anyways
        */
	user_time = time;
    }
}

- (void) setupDecorAndFunctions
{
    /* start with everything (cept fullscreen) */
    decorations = 
        (OB_FRAME_DECOR_TITLEBAR |
         OB_FRAME_DECOR_HANDLE |
         OB_FRAME_DECOR_GRIPS |
         OB_FRAME_DECOR_BORDER |
         OB_FRAME_DECOR_ICON |
         OB_FRAME_DECOR_ALLDESKTOPS |
         OB_FRAME_DECOR_ICONIFY |
         OB_FRAME_DECOR_MAXIMIZE |
         OB_FRAME_DECOR_SHADE |
         OB_FRAME_DECOR_CLOSE);
    functions = 
        (OB_CLIENT_FUNC_RESIZE |
         OB_CLIENT_FUNC_MOVE |
         OB_CLIENT_FUNC_ICONIFY |
         OB_CLIENT_FUNC_MAXIMIZE |
         OB_CLIENT_FUNC_SHADE |
         OB_CLIENT_FUNC_CLOSE);

    if (!(min_size.width < max_size.width ||
          min_size.height < max_size.height))
        functions &= ~OB_CLIENT_FUNC_RESIZE;

    switch (type) {
    case OB_CLIENT_TYPE_NORMAL:
        /* normal windows retain all of the possible decorations and
           functionality, and are the only windows that you can fullscreen */
        functions |= OB_CLIENT_FUNC_FULLSCREEN;
        break;

    case OB_CLIENT_TYPE_DIALOG:
    case OB_CLIENT_TYPE_UTILITY:
        /* these windows cannot be maximized */
        functions &= ~OB_CLIENT_FUNC_MAXIMIZE;
        break;

    case OB_CLIENT_TYPE_MENU:
    case OB_CLIENT_TYPE_TOOLBAR:
        /* these windows get less functionality */
        functions &= ~(OB_CLIENT_FUNC_ICONIFY | OB_CLIENT_FUNC_RESIZE);
        break;

    case OB_CLIENT_TYPE_DESKTOP:
    case OB_CLIENT_TYPE_DOCK:
    case OB_CLIENT_TYPE_SPLASH:
        /* none of these windows are manipulated by the window manager */
        decorations = 0;
        functions = 0;
        break;
    }

    /* Mwm Hints are applied subtractively to what has already been chosen for
       decor and functionality */
    if (mwmhints.flags & OB_MWM_FLAG_DECORATIONS) {
        if (! (mwmhints.decorations & OB_MWM_DECOR_ALL)) {
            if (! ((mwmhints.decorations & OB_MWM_DECOR_HANDLE) ||
                   (mwmhints.decorations & OB_MWM_DECOR_TITLE))) 
	    {
                /* if the mwm hints request no handle or title, then all
                   decorations are disabled, but keep the border if that's
		   specified */
		if (mwmhints.decorations & OB_MWM_DECOR_BORDER) {
		  decorations = OB_FRAME_DECOR_BORDER;
		} else {
		  decorations = 0;
		}
	    }
        }
    }

    if (mwmhints.flags & OB_MWM_FLAG_FUNCTIONS) {
        if (! (mwmhints.functions & OB_MWM_FUNC_ALL)) {
            if (! (mwmhints.functions & OB_MWM_FUNC_RESIZE))
                functions &= ~OB_CLIENT_FUNC_RESIZE;
            if (! (mwmhints.functions & OB_MWM_FUNC_MOVE))
                functions &= ~OB_CLIENT_FUNC_MOVE;
            /* dont let mwm hints kill any buttons
               if (! (mwmhints.functions & OB_MWM_FUNC_ICONIFY))
                 functions &= ~OB_CLIENT_FUNC_ICONIFY;
               if (! (mwmhints.functions & OB_MWM_FUNC_MAXIMIZE))
                 functions &= ~OB_CLIENT_FUNC_MAXIMIZE;
            */
            /* dont let mwm hints kill the close button
               if (! (mwmhints.functions & MwmFunc_Close))
                 functions &= ~OB_CLIENT_FUNC_CLOSE; */
        }
    }

    if ([self isGNUstep]) {
        /* Override the decoration */
	decorations = functions = 0;
	if (gnustep_attr.flags & GSWindowStyleAttr) {
	  if (gnustep_attr.window_style == NSBorderlessWindowMask) {
            /* Borderless */
            if (config_theme_keepborder)
              decorations |= OB_FRAME_DECOR_BORDER;
          } else {
            decorations |= OB_FRAME_DECOR_BORDER;
	  
	    if (gnustep_attr.window_style & NSTitledWindowMask) {
	      decorations |= OB_FRAME_DECOR_TITLEBAR |
	                     OB_FRAME_DECOR_SHADE;
	      functions |= OB_CLIENT_FUNC_MOVE |
	                   OB_CLIENT_FUNC_SHADE;
	    }
	    if (gnustep_attr.window_style & NSClosableWindowMask) {
	      decorations |= OB_FRAME_DECOR_CLOSE;
	        functions |= OB_CLIENT_FUNC_CLOSE;
	    }
	    if (gnustep_attr.window_style & NSMiniaturizableWindowMask) {
	      decorations |= OB_FRAME_DECOR_ICONIFY;
	      functions |= OB_CLIENT_FUNC_ICONIFY;
	    }
	    if (gnustep_attr.window_style & NSResizableWindowMask) {
	      decorations |= OB_FRAME_DECOR_HANDLE |
	                     OB_FRAME_DECOR_GRIPS |
	                     OB_FRAME_DECOR_MAXIMIZE;
	      functions |= OB_CLIENT_FUNC_RESIZE |
	                   OB_CLIENT_FUNC_MAXIMIZE;
	    }
	  } 
	}
    }

    if (!(functions & OB_CLIENT_FUNC_SHADE))
        decorations &= ~OB_FRAME_DECOR_SHADE;
    if (!(functions & OB_CLIENT_FUNC_ICONIFY))
        decorations &= ~OB_FRAME_DECOR_ICONIFY;
    if (!(functions & OB_CLIENT_FUNC_RESIZE))
        decorations &= ~OB_FRAME_DECOR_GRIPS;

    /* can't maximize without moving/resizing */
    if (!((functions & OB_CLIENT_FUNC_MAXIMIZE) &&
          (functions & OB_CLIENT_FUNC_MOVE) &&
          (functions & OB_CLIENT_FUNC_RESIZE))) {
        functions &= ~OB_CLIENT_FUNC_MAXIMIZE;
        decorations &= ~OB_FRAME_DECOR_MAXIMIZE;
    }

    /* kill the handle on fully maxed windows */
    if (max_vert && max_horz)
        decorations &= ~OB_FRAME_DECOR_HANDLE;

    /* finally, the user can have requested no decorations, which overrides
       everything (but doesnt give it a border if it doesnt have one) */
    if (undecorated) {
        if (config_theme_keepborder)
            decorations &= OB_FRAME_DECOR_BORDER;
        else
            decorations = 0;
    }

    /* if we don't have a titlebar, then we cannot shade! */
    if (!(decorations & OB_FRAME_DECOR_TITLEBAR))
        functions &= ~OB_CLIENT_FUNC_SHADE;

    /* now we need to check against rules for the client's current state */
    if (fullscreen) {
        functions &= (OB_CLIENT_FUNC_CLOSE |
                       OB_CLIENT_FUNC_FULLSCREEN |
                       OB_CLIENT_FUNC_ICONIFY);
        decorations = 0;
    }

    [self changeAllowedActions];

    if (frame) {
        /* adjust the client's decorations, etc. */
	[self reconfigure];
    }
}

- (void) getType
{
    unsigned int num, i;
    unsigned long *val;

    type = -1;
  
    if (PROP_GETA32(window, net_wm_window_type, atom, &val, &num)) {
        /* use the first value that we know about in the array */
        for (i = 0; i < num; ++i) {
            if (val[i] == prop_atoms.net_wm_window_type_desktop)
                type = OB_CLIENT_TYPE_DESKTOP;
            else if (val[i] == prop_atoms.net_wm_window_type_dock)
                type = OB_CLIENT_TYPE_DOCK;
            else if (val[i] == prop_atoms.net_wm_window_type_toolbar)
                type = OB_CLIENT_TYPE_TOOLBAR;
            else if (val[i] == prop_atoms.net_wm_window_type_menu)
                type = OB_CLIENT_TYPE_MENU;
            else if (val[i] == prop_atoms.net_wm_window_type_utility)
                type = OB_CLIENT_TYPE_UTILITY;
            else if (val[i] == prop_atoms.net_wm_window_type_splash)
                type = OB_CLIENT_TYPE_SPLASH;
            else if (val[i] == prop_atoms.net_wm_window_type_dialog)
                type = OB_CLIENT_TYPE_DIALOG;
            else if (val[i] == prop_atoms.net_wm_window_type_normal)
                type = OB_CLIENT_TYPE_NORMAL;
            else if (val[i] == prop_atoms.kde_net_wm_window_type_override) {
                /* prevent this window from getting any decor or
                   functionality */
                mwmhints.flags &= (OB_MWM_FLAG_FUNCTIONS |
                                         OB_MWM_FLAG_DECORATIONS);
                mwmhints.decorations = 0;
                mwmhints.functions = 0;
            }
            if (type != (ObClientType) -1)
                break; /* grab the first legit type */
        }
        free(val);
    }
    
    if (type == (ObClientType) -1) {
        /*the window type hint was not set, which means we either classify
          ouroself as a normal window or a dialog, depending on if we are a
          transient. */
        if (transient)
            type = OB_CLIENT_TYPE_DIALOG;
        else
            type = OB_CLIENT_TYPE_NORMAL;
    }
}

- (AZClientIcon *) iconWithWidth: (int) w height: (int) h
{
    AZClientIcon *ret = nil;
    static AZClientIcon *deficon;
    if (deficon == nil)
    {
      deficon = [[AZClientIcon alloc] init];
    }

    if (!(ret = [self iconRecursiveWithWidth: w height: h])) {
	[deficon setWidth: 48];
	[deficon setHeight: 48];
	[deficon setData: ob_rr_theme->def_win_icon];
	return deficon;
    }
    return ret;
}

- (AZClient *) searchFocusParent
{
    if (transient_for) {
        if (transient_for != OB_TRAN_GROUP) {
	    if ([transient_for focused])
                return transient_for;
        } else {
            int i, count = [[group members] count];
	    for (i = 0; i < count; i++) {
	      AZClient *c = [group memberAtIndex: i];
                /* checking transient_for prevents infinate loops! */
                if (c != self && !transient_for)
		    if ([c focused])
                        return c;
            }
        }
    }

    return nil;
}

- (AZClient *) searchFocusTree
{
    AZClient *ret = nil;
    int j, jcount = [transients count];
    AZClient *data = nil;
    for (j = 0; j < jcount; j++) {
	data = [transients objectAtIndex: j];
	if ([data focused])
	  return data;
	if ((ret = [data searchFocusTree]))
	  return ret;
    }
    return nil;
}

- (AZClient *) searchModalChild
{
    AZClient *ret = nil;
  
    int j, jcount = [transients count];
    for (j = 0; j < jcount; j++) {
	AZClient *c = [transients objectAtIndex: j];
	if ((ret = [c searchModalChild])) return ret;
	if ([c modal]) return c;
    }
    return nil;
}

- (AZClient *) searchTransient: (AZClient *) search;
{
    int j, jcount = [transients count];
    AZClient *temp = nil;
    for (j = 0; j < jcount; j++) {
	temp = [transients objectAtIndex: j];
	if (temp == search)
	    return search;
	if ([temp searchTransient: search])
	    return search;
    }
    return nil;
}

- (AZClient *) findDirectional: (ObDirection) dir
{
    /* this be mostly ripped from fvwm */
    int my_cx, my_cy, his_cx, his_cy;
    int offset = 0;
    int distance = 0;
    int score, best_score;
    AZClient *best_client = nil, *cur = nil;
    AZClientManager *cManager = [AZClientManager defaultManager];

    if ([cManager count] == 0) return NULL;

    /* first, find the centre coords of the currently focused window */
    my_cx = [frame area].x + [frame area].width / 2;
    my_cy = [frame area].y + [frame area].height / 2;

    best_score = -1;
    best_client = NULL;

    int i, count = [cManager count];
    for (i = 0; i < count; i++) {
	cur = [cManager clientAtIndex: i];

        /* the currently selected window isn't interesting */
        if(cur == self)
            continue;
        if (![cur normal])
            continue;
        /* using c->desktop instead of screen_desktop doesn't work if the
         * current window was omnipresent, hope this doesn't have any other
         * side effects */
        if([[AZScreen defaultScreen] desktop] != [cur desktop] && [cur desktop] != DESKTOP_ALL)
            continue;
        if([cur iconic])
            continue;
        if(!([cur focusTarget] == cur && [cur can_focus]))
            continue;

        /* find the centre coords of this window, from the
         * currently focused window's point of view */
        his_cx = ([[cur frame] area].x - my_cx) + [[cur frame] area].width / 2;
        his_cy = ([[cur frame] area].y - my_cy) + [[cur frame] area].height / 2;

        if(dir == OB_DIRECTION_NORTHEAST || dir == OB_DIRECTION_SOUTHEAST ||
           dir == OB_DIRECTION_SOUTHWEST || dir == OB_DIRECTION_NORTHWEST) {
            int tx;
            /* Rotate the diagonals 45 degrees counterclockwise.
             * To do this, multiply the matrix /+h +h\ with the
             * vector (x y).                   \-h +h/
             * h = sqrt(0.5). We can set h := 1 since absolute
             * distance doesn't matter here. */
            tx = his_cx + his_cy;
            his_cy = -his_cx + his_cy;
            his_cx = tx;
        }

        switch(dir) {
        case OB_DIRECTION_NORTH:
        case OB_DIRECTION_SOUTH:
        case OB_DIRECTION_NORTHEAST:
        case OB_DIRECTION_SOUTHWEST:
            offset = (his_cx < 0) ? -his_cx : his_cx;
            distance = ((dir == OB_DIRECTION_NORTH ||
                         dir == OB_DIRECTION_NORTHEAST) ?
                        -his_cy : his_cy);
            break;
        case OB_DIRECTION_EAST:
        case OB_DIRECTION_WEST:
        case OB_DIRECTION_SOUTHEAST:
        case OB_DIRECTION_NORTHWEST:
            offset = (his_cy < 0) ? -his_cy : his_cy;
            distance = ((dir == OB_DIRECTION_WEST ||
                         dir == OB_DIRECTION_NORTHWEST) ?
                        -his_cx : his_cx);
            break;
        }

        /* the target must be in the requested direction */
        if(distance <= 0)
            continue;

        /* Calculate score for this window.  The smaller the better. */
        score = distance + offset;

        /* windows more than 45 degrees off the direction are
         * heavily penalized and will only be chosen if nothing
         * else within a million pixels */
        if(offset > distance)
            score += 1000000;

        if(best_score == -1 || score < best_score)
            best_client = cur,
                best_score = score;
    }

    return best_client;
}

/* finds the nearest edge in the given direction from the current client
 * note to oself: the edge is the -frame- edge (the actual one), not the
 * client edge.
 */
- (int) directionalEdgeSearch: (ObDirection) dir
{
    int dest, monitor_dest;
    int my_edge_start, my_edge_end, my_offset;
    Rect *a, *monitor;
    AZScreen *screen = [AZScreen defaultScreen];
    AZClientManager *cManager = [AZClientManager defaultManager];
    int i, count;
    
    if ([cManager count] == 0) return -1;

    a = [screen areaOfDesktop: desktop];
    monitor = [screen areaOfDesktop: desktop monitor: [self monitor]];

    switch(dir) {
    case OB_DIRECTION_NORTH:
        my_edge_start = [frame area].x;
        my_edge_end = [frame area].x + [frame area].width;
        my_offset = [frame area].y;
        
        /* default: top of screen */
        dest = a->y;
        monitor_dest = monitor->y;
        /* if the monitor edge comes before the screen edge, */
        /* use that as the destination instead. (For xinerama) */
        if (monitor_dest != dest && my_offset > monitor_dest)
            dest = monitor_dest; 

	count = [cManager count];
	for (i = 0; ((i < count) && (my_offset != dest)); i++) {
	    AZClient *cur = [cManager clientAtIndex: i];
            int his_edge_start, his_edge_end, his_offset;

            if(cur == self)
                continue;
            if(![cur normal])
                continue;
            if([screen desktop] != [cur desktop] && [cur desktop] != DESKTOP_ALL)
                continue;
            if([cur iconic])
                continue;
            if([cur layer] < layer && !config_resist_layers_below)
                continue;

            his_edge_start = [[cur frame] area].x;
            his_edge_end = [[cur frame] area].x + [[cur frame] area].width;
            his_offset = [[cur frame] area].y + [[cur frame] area].height;

            if(his_offset + 1 > my_offset)
                continue;

            if(his_offset < dest)
                continue;
            
            if(his_edge_start >= my_edge_start &&
               his_edge_start <= my_edge_end)
                dest = his_offset;

            if(my_edge_start >= his_edge_start &&
               my_edge_start <= his_edge_end)
                dest = his_offset;

        }
        break;
    case OB_DIRECTION_SOUTH:
        my_edge_start = [frame area].x;
        my_edge_end = [frame area].x + [frame area].width;
        my_offset = [frame area].y + [frame area].height;

        /* default: bottom of screen */
        dest = a->y + a->height;
        monitor_dest = monitor->y + monitor->height;
        /* if the monitor edge comes before the screen edge, */
        /* use that as the destination instead. (For xinerama) */
        if (monitor_dest != dest && my_offset < monitor_dest)
            dest = monitor_dest; 

        count = [cManager count];
	for (i = 0; ((i < count) && (my_offset != dest)); i++) {
	    AZClient *cur = [cManager clientAtIndex: i];
            int his_edge_start, his_edge_end, his_offset;

            if(cur == self)
                continue;
            if(![cur normal])
                continue;
            if([screen desktop] != [cur desktop] && [cur desktop] != DESKTOP_ALL)
                continue;
            if([cur iconic])
                continue;
            if([cur layer] < layer && !config_resist_layers_below)
                continue;

            his_edge_start = [[cur frame] area].x;
            his_edge_end = [[cur frame] area].x + [[cur frame] area].width;
            his_offset = [[cur frame] area].y;


            if(his_offset - 1 < my_offset)
                continue;
            
            if(his_offset > dest)
                continue;
            
            if(his_edge_start >= my_edge_start &&
               his_edge_start <= my_edge_end)
                dest = his_offset;

            if(my_edge_start >= his_edge_start &&
               my_edge_start <= his_edge_end)
                dest = his_offset;

        }
        break;
    case OB_DIRECTION_WEST:
        my_edge_start = [frame area].y;
        my_edge_end = [frame area].y + [frame area].height;
        my_offset = [frame area].x;

        /* default: leftmost egde of screen */
        dest = a->x;
        monitor_dest = monitor->x;
        /* if the monitor edge comes before the screen edge, */
        /* use that as the destination instead. (For xinerama) */
        if (monitor_dest != dest && my_offset > monitor_dest)
            dest = monitor_dest;            

        count = [cManager count];
	for (i = 0; ((i < count) && (my_offset != dest)); i++) {
	    AZClient *cur = [cManager clientAtIndex: i];
            int his_edge_start, his_edge_end, his_offset;

            if(cur == self)
                continue;
            if(![cur normal])
                continue;
            if([screen desktop] != [cur desktop] && [cur desktop] != DESKTOP_ALL)
                continue;
            if([cur iconic])
                continue;
            if([cur layer] < layer && !config_resist_layers_below)
                continue;

            his_edge_start = [[cur frame] area].y;
            his_edge_end = [[cur frame] area].y + [[cur frame] area].height;
            his_offset = [[cur frame] area].x + [[cur frame] area].width;

            if(his_offset + 1 > my_offset)
                continue;
            
            if(his_offset < dest)
                continue;
            
            if(his_edge_start >= my_edge_start &&
               his_edge_start <= my_edge_end)
                dest = his_offset;

            if(my_edge_start >= his_edge_start &&
               my_edge_start <= his_edge_end)
                dest = his_offset;
                

        }
        break;
    case OB_DIRECTION_EAST:
        my_edge_start = [frame area].y;
        my_edge_end = [frame area].y + [frame area].height;
        my_offset = [frame area].x + [frame area].width;
        
        /* default: rightmost edge of screen */
        dest = a->x + a->width;
        monitor_dest = monitor->x + monitor->width;
        /* if the monitor edge comes before the screen edge, */
        /* use that as the destination instead. (For xinerama) */
        if (monitor_dest != dest && my_offset < monitor_dest)
            dest = monitor_dest;            

        count = [cManager count];
	for (i = 0; ((i < count) && (my_offset != dest)); i++) {
	    AZClient *cur = [cManager clientAtIndex: i];
            int his_edge_start, his_edge_end, his_offset;

            if(cur == self)
                continue;
            if(![cur normal])
                continue;
            if([screen desktop] != [cur desktop] && [cur desktop] != DESKTOP_ALL)
                continue;
            if([cur iconic])
                continue;
            if([cur layer] < layer && !config_resist_layers_below)
                continue;

            his_edge_start = [[cur frame] area].y;
            his_edge_end = [[cur frame] area].y + [[cur frame] area].height;
            his_offset = [[cur frame] area].x;

            if(his_offset - 1 < my_offset)
                continue;
            
            if(his_offset > dest)
                continue;
            
            if(his_edge_start >= my_edge_start &&
               his_edge_start <= my_edge_end)
                dest = his_offset;

            if(my_edge_start >= his_edge_start &&
               my_edge_start <= his_edge_end)
                dest = his_offset;

        }
        break;
    case OB_DIRECTION_NORTHEAST:
    case OB_DIRECTION_SOUTHEAST:
    case OB_DIRECTION_NORTHWEST:
    case OB_DIRECTION_SOUTHWEST:
        /* not implemented */
    default:
	NSAssert(0, @"Should not reach here");
        dest = 0; /* suppress warning */
    }
    return dest;
}

- (void) setLayer: (int) l
{
    if (l < 0) {
        [self set_below: YES];
        [self set_above: NO];
    } else if (l == 0) {
        [self set_below: NO];
       	[self set_above: NO];
    } else {
        [self set_below: NO];
        [self set_above: YES];
    }
    [self calcLayer];
    [self changeState]; /* reflect this in the state hints */
}

- (void) setUndecorated: (BOOL) u
{
    if (undecorated != u) {
        undecorated = u;
	[self setupDecorAndFunctions];
        /* Make sure the client knows it might have moved. Maybe there is a
         * better way of doing this so only one client_configure is sent, but
         * since 125 of these are sent per second when moving the window (with
         * user = NO) i doubt it matters much.
         */
	[self configureToCorner: OB_CORNER_TOPLEFT
		x: area.x y: area.y width: area.width height: area.height
		user: YES final: YES];
        [self changeState]; /* reflect this in the state hints */
    }
}

- (unsigned int) monitor
{
    Rect a = [[self frame] area];
    return [[AZScreen defaultScreen] findMonitor: &a];
}

- (NSArray *) searchAllTopParents
{
    NSMutableArray *ret = [[NSMutableArray alloc] init];

    /* move up the direct transient chain as far as possible */
    AZClient *t_for = self;
    while ([t_for transient_for] && [t_for transient_for] != OB_TRAN_GROUP)
      t_for = [t_for transient_for];

    if ([t_for transient_for] == nil)
    {
        [ret addObject: t_for]; 
    }
    else
    {
	if ([t_for group] == nil)
	    NSLog(@"Internal Error: not group");

	NSEnumerator *e = [[[t_for group] members] objectEnumerator];
	AZClient *c = nil;
	while ((c = [e nextObject]))
	{
	    if (([c transient_for] == nil) && [c normal])
		[ret insertObject: c atIndex: 0];
 	}
	if ([ret count] == 0) /* no group parents */
	    [ret addObject: t_for];
    }
    return AUTORELEASE(ret);
}

- (AZClient *) searchTopParent
{
    /* move up the direct transient chain as far as possible */
    AZClient *t_for = self;
    while ([t_for transient_for] && [t_for transient_for] != OB_TRAN_GROUP &&
	   [t_for normal])
    {
      t_for = [t_for transient_for];
    }

    return t_for;
}

- (BOOL) hasDirectChild: (AZClient *) child
{
    while (child != self &&
           [child transient_for] && [child transient_for] != OB_TRAN_GROUP)
        child = [child transient_for];
    return [child isEqual: self];
}

- (void) updateSmClientId;
{
    DESTROY(sm_client_id);
    NSString *data = nil;

    if ((!PROP_GETS(window, sm_client_id, locale, &data)) && (group))
    {
       PROP_GETS([group leader], sm_client_id, locale, &data);
    }

    if (data) {
        ASSIGNCOPY(sm_client_id, data);
    }
}

- (BOOL) hasGroupSiblings
{
  return (group && ([[group members] count] > 1));
}

/* For AZClientManager */
- (void) getAll
{
    [self getArea];
    [self getMwmHints];

    /* The transient hint is used to pick a type, but the type can also affect
       transiency (dialogs are always made transients of their group if they
       have one). This is Havoc's idea, but it is needed to make some apps
       work right (eg tsclient). */
    [self updateTransientFor];
    [self getType];/* this can change the mwmhints for special cases */
    [self getState];
    [self updateTransientFor];

    [self updateWmhints];
    [self getStartupId];
    [self getDesktop];/* uses transient data/group/startup id if a
                                desktop is not specified */
    [self getShaped];
    [self getLayer]; /* if layer hasn't been specified, get it from
                               other sources if possible */

    {
        /* a couple type-based defaults for new windows */

        /* this makes sure that these windows appear on all desktops */
        if (type == OB_CLIENT_TYPE_DESKTOP)
            desktop = DESKTOP_ALL;
    }

    [self updateProtocols];

    [self getGravity]; /* get the attribute gravity */
    [self updateNormalHints]; /* this may override the attribute
                                         gravity */

    /* Need class information to tell whether it is a GNUstpe window */
    [self updateClass];
    if ([self isGNUstep])
      [self updateGNUstepWMAttributes];

    /* got the type, the mwmhints, the protocols, and the normal hints
       (min/max sizes), so we're ready to set up the decorations/functions */
    [self setupDecorAndFunctions];
  
    [self getClientMachine];
    [self updateTitle];
    [self updateSmClientId];
    [self updateStrut];
    [self updateIcons];
    [self updateUserTime];
}

- (void) restoreSessionState
{
    AZSessionState *s = nil;
    if (!(s = session_state_find(self)))
        return;

    session = s;

    RECT_SET_POINT(area, [session x], [session y]);
    positioned = PPosition;
    if ([session w] > 0)
	area.width = [session w];
    if ([session h] > 0)
	area.height = [session h];
    XResizeWindow(ob_display, window,
                  area.width, area.height);

    desktop = ([session desktop] == DESKTOP_ALL ?
                     [session desktop] :
                     MIN([[AZScreen defaultScreen] numberOfDesktops] - 1, [session desktop]));
    PROP_SET32(window, net_wm_desktop, cardinal, desktop);

    shaded = [session shaded];
    iconic = [session iconic];
    skip_pager = [session skip_pager];
    skip_taskbar = [session skip_taskbar];
    fullscreen = [session fullscreen];
    above = [session above];
    below = [session below];
    max_horz = [session max_horz];
    max_vert = [session max_vert];
}

- (void) changeWMState
{
    unsigned long state[2];
    long old;

    old = [self wmstate];

    if (shaded || iconic || ![frame visible])
        wmstate = IconicState;
    else
        wmstate = NormalState;

    if (old != wmstate) {
        PROP_MSG(window, kde_wm_change_state,
                 wmstate, 1, 0, 0);

        state[0] = wmstate;
        state[1] = None;
        PROP_SETA32(window, wm_state, wm_state, state, 2);
    }
}

- (void) changeState
{
    unsigned long netstate[11];
    unsigned int num;

    num = 0;
    if (modal)
        netstate[num++] = prop_atoms.net_wm_state_modal;
    if (shaded)
        netstate[num++] = prop_atoms.net_wm_state_shaded;
    if (iconic)
        netstate[num++] = prop_atoms.net_wm_state_hidden;
    if (skip_taskbar)
        netstate[num++] = prop_atoms.net_wm_state_skip_taskbar;
    if (skip_pager)
        netstate[num++] = prop_atoms.net_wm_state_skip_pager;
    if (fullscreen)
        netstate[num++] = prop_atoms.net_wm_state_fullscreen;
    if (max_vert)
        netstate[num++] = prop_atoms.net_wm_state_maximized_vert;
    if (max_horz)
        netstate[num++] = prop_atoms.net_wm_state_maximized_horz;
    if (above)
        netstate[num++] = prop_atoms.net_wm_state_above;
    if (below)
        netstate[num++] = prop_atoms.net_wm_state_below;
    if (demands_attention)
        netstate[num++] = prop_atoms.net_wm_state_demands_attention;
    if (undecorated)
        netstate[num++] = prop_atoms.ob_wm_state_undecorated;
    PROP_SETA32(window, net_wm_state, atom, netstate, num);

    if (frame)
	[frame adjustState];
}

- (void) toggleBorder: (BOOL) show
{
    /* adjust our idea of where the client is, based on its border. When the
       border is removed, the client should now be considered to be in a
       different position.
       when re-adding the border to the client, the same operation needs to be
       reversed. */
    int oldx = area.x, oldy = area.y;
    int x = oldx, y = oldy;
    switch(gravity) {
    default:
    case NorthWestGravity:
    case WestGravity:
    case SouthWestGravity:
        break;
    case NorthEastGravity:
    case EastGravity:
    case SouthEastGravity:
        if (show) x -= border_width * 2;
        else      x += border_width * 2;
        break;
    case NorthGravity:
    case SouthGravity:
    case CenterGravity:
    case ForgetGravity:
    case StaticGravity:
        if (show) x -= border_width;
        else      x += border_width;
        break;
    }
    switch(gravity) {
    default:
    case NorthWestGravity:
    case NorthGravity:
    case NorthEastGravity:
        break;
    case SouthWestGravity:
    case SouthGravity:
    case SouthEastGravity:
        if (show) y -= border_width * 2;
        else      y += border_width * 2;
        break;
    case WestGravity:
    case EastGravity:
    case CenterGravity:
    case ForgetGravity:
    case StaticGravity:
        if (show) y -= border_width;
        else      y += border_width;
        break;
    }
    area.x = x;
    area.y = y;

    if (show) {
        XSetWindowBorderWidth(ob_display, window, border_width);
        /* set border_width to 0 because there is no border to add into
           calculations anymore */
        border_width = 0;
    } else
        XSetWindowBorderWidth(ob_display, window, 0);
}

- (void) applyStartupStateAtX: (int) x y: (int) y
{
    BOOL pos = NO; /* has the window's position been configured? */
    int ox, oy;

    /* save the position, and set self->area for these to use */
    ox = area.x;
    oy = area.y;
    area.x = x;
    area.y = y;

    /* these are in a carefully crafted order.. */

    if (iconic) {
        iconic = NO;
	[self iconify: YES currentDesktop: NO];
    }
    if (fullscreen) {
        fullscreen = NO;
	[self fullscreen: YES];
	pos = YES;
    }
    if (undecorated) {
        undecorated = NO;
        [self setUndecorated: YES];
    }
    if (shaded) {
        shaded = NO;
	[self shade: YES];
    }
    if (demands_attention) 
    {
        demands_attention = NO;
	[self hilite: YES];
    }

  
    if (max_vert && max_horz) {
        max_vert = NO;
	max_horz = NO;
	[self maximize: YES direction: 0];
	pos = YES;
    } else if (max_vert) {
        max_vert = NO;
	[self maximize: YES direction: 2];
	pos = YES;
    } else if (max_horz) {
        max_horz = NO;
	[self maximize: YES direction: 1];
	pos = YES;
    }

    /* if the client didn't get positioned yet, then do so now
       call client_move even if the window is not being moved anywhere, because
       when we reparent it and decorate it, it is getting moved and we need to
       be telling it so with a ConfigureNotify event.
    */
    if (!pos) {
        /* use the saved position */
        area.x = ox;
        area.y = oy;
	[self moveToX: x y: y];
    }

    /* nothing to do for the other states:
       skip_taskbar
       skip_pager
       modal
       above
       below
    */
}

- (void) restoreSessionStacking
{
    if (!session) return;

    int i, index = [session_saved_state indexOfObject: session];
    for (i = index-1; i > -1; i--) {
        AZSessionState *s = [session_saved_state objectAtIndex: i];
        AZClientManager *cManager = [AZClientManager defaultManager];
        int i, count = [cManager count];
	BOOL found = NO;
	AZClient *data = nil;
	for (i = 0; i < count; i++)
	{
	    data = [cManager clientAtIndex: i];
            if (session_state_cmp(s, data))
	    {
		found = YES;
                break;
	    }
	}
        if (found) {
	    [self calcLayer];
	    [[AZStacking stacking] moveWindow: self belowWindow: data];
            break;
        }
    }
}

- (void) show
{
    if ([self shouldShow])
    {
      [[self frame] show];
    }

    /* According to the ICCCM (sec 4.1.3.1) when a window is not visible, it
       needs to be in IconicState. This includes when it is on another
       desktop!
    */
    [self changeWMState];
}

- (void) hide
{
    if ([self shouldShow] == NO)
    {
      [[self frame] hide];
    }

    /* According to the ICCCM (sec 4.1.3.1) when a window is not visible, it
       needs to be in IconicState. This includes when it is on another
       desktop!
    */
    [self changeWMState];
}

- (void) showhide
{
    if ([self shouldShow])
    {
	[frame show];
    }
    else
    {
	[frame hide];
    }

    /* According to the ICCCM (sec 4.1.3.1) when a window is not visible, it
       needs to be in IconicState. This includes when it is on another
       desktop!
    */
    [self changeWMState];
}

- (unsigned int) opacity
{
	return opacity;
}

- (void) setOpacity: (unsigned int) o
{
	/* Full opacity */
	if (o == 0xffffff)
		PROP_ERASE(window, net_wm_window_opacity);
	else if (opacity != o)
		PROP_SET32([frame window], net_wm_window_opacity, cardinal, o);

	opacity = o;
}

- (BOOL) hasShadow
{
	return has_shadow;
}

- (void) setHasShadow: (BOOL) flag
{
	if (has_shadow != flag)
	{	
		NSLog(@"Change shadow %d", flag);
		has_shadow = flag;
	}
}


/* Accessories */
- (AZFrame *) frame { return frame; }
- (void) set_frame: (AZFrame *) f { ASSIGN(frame, f); }

- (Window) window { return window; }
//- (Window *) windowPointer { return &window; }
- (int) ignore_unmaps { return ignore_unmaps; }
- (void) set_window: (Window) w { window = w; }
- (void) set_ignore_unmaps: (int) i { ignore_unmaps = i; }

- (AZGroup *) group { return group; }
- (void) set_group: (AZGroup *) g { group = g; }

- (AZSessionState *) session { return session; }
- (void) set_session: (AZSessionState *) s { session = s; }

- (BOOL) transient { return transient; }
- (AZClient *) transient_for { return transient_for; }
- (void) set_transient: (BOOL) t { transient = t; }
- (void) set_transient_for: (AZClient *) t { transient_for = t; }

- (NSArray *) transients { return transients; }
- (void) removeTransient: (AZClient *) c { [transients removeObject: c]; }
- (void) addTransient: (AZClient *) c { [transients addObject: c]; }
- (void) removeAllTransients { [transients removeAllObjects]; }

- (unsigned int) desktop { return desktop; }
- (NSString *) startup_id { return startup_id; }
- (void) set_desktop: (unsigned int) d  { desktop = d; }
- (void) set_startup_id: (NSString *) s { ASSIGN(startup_id, s); }

- (NSString *) title { return title; }
- (NSString *) icon_title { return icon_title; }
- (NSString *) name { return name; }
- (NSString *) class { return class; }
- (NSString *) role { return role; }
- (NSString *) sm_client_id { return sm_client_id; }
- (ObClientType) type { return type; }
- (void) set_title: (NSString *) t { ASSIGN(title, t); }
- (void) set_icon_title: (NSString *) i { ASSIGN(icon_title, i); }
- (void) set_name: (NSString *) n { ASSIGN(name, n); }
- (void) set_class: (NSString *) c { ASSIGN(class, c); }
- (void) set_role: (NSString *) r { ASSIGN(role, r); }
- (void) set_sm_client_id: (NSString *) s { ASSIGN(sm_client_id, s); }
- (void) set_type: (ObClientType) t { type = t; }

- (Rect) area { return area; }
- (Rect) pre_max_area { return pre_max_area; }
- (Rect) pre_fullscreen_area { return pre_fullscreen_area; }
- (StrutPartial) strut { return strut; }
- (Size) logical_size { return logical_size; }
- (unsigned int) border_width { return border_width; }
- (float) min_ratio { return min_ratio; }
- (float) max_ratio { return max_ratio; }
- (Size) min_size { return min_size; }
- (Size) max_size { return max_size; }
- (Size) size_inc { return size_inc; }
- (Size) base_size { return base_size; }
- (ObMwmHints) mwmhints { return mwmhints; }
- (void) set_area: (Rect) r { area = r; }
- (void) set_pre_max_area: (Rect) r { pre_max_area = r; }
- (void) set_pre_fullscreen_area: (Rect) r { pre_fullscreen_area = r; }
- (void) set_strut: (StrutPartial) r { strut= r; }
- (void) set_logical_size: (Size) r { logical_size = r; }
- (void) set_border_width: (unsigned int) r { border_width = r; }
- (void) set_min_ratio: (float) r { min_ratio = r; }
- (void) set_max_ratio: (float) r { max_ratio = r; }
- (void) set_min_size: (Size) r { min_size = r; }
- (void) set_max_size: (Size) r { max_size = r; }
- (void) set_size_inc: (Size) r { size_inc = r; }
- (void) set_base_size: (Size) r { base_size = r; }
- (void) set_mwmhints: (ObMwmHints) r { mwmhints = r; }

- (int) gravity { return gravity; }
- (long) wmstate { return wmstate; }
- (BOOL) delete_window { return delete_window; }
- (unsigned int) positioned { return positioned; }
- (ObStackingLayer) layer { return layer; }
- (void) set_gravity: (int) i { gravity = i; }
- (void) set_wmstate: (long) l { wmstate = l; }
- (void) set_delete_window: (BOOL) b { delete_window = b; }
- (void) set_positioned: (unsigned int)  ui { positioned = ui; }
- (void) set_layer: (ObStackingLayer) l { layer = l; }

- (BOOL) can_focus { return can_focus; }
- (BOOL) focus_notify { return focus_notify; }
- (BOOL) shaped { return shaped; }
- (void) set_can_focus: (BOOL) b { can_focus = b; }
- (void) set_focus_notify: (BOOL) b { focus_notify = b; }
- (void) set_shaped: (BOOL) b { shaped = b; }

- (BOOL) modal { return modal; }
- (BOOL) shaded { return shaded; }
- (BOOL) iconic { return iconic; }
- (BOOL) max_vert { return max_vert; }
- (BOOL) max_horz { return max_horz; }
- (BOOL) skip_pager { return skip_pager; }
- (BOOL) skip_taskbar { return skip_taskbar; }
- (BOOL) fullscreen { return fullscreen; }
- (BOOL) above { return above; }
- (BOOL) below { return below; }
- (void) set_modal: (BOOL) b { modal = b; }
- (void) set_shaded: (BOOL) b { shaded = b; }
- (void) set_iconic: (BOOL) b { iconic = b; }
- (void) set_max_vert: (BOOL) b { max_vert = b; }
- (void) set_max_horz: (BOOL) b { max_horz = b; }
- (void) set_skip_pager: (BOOL) b { skip_pager = b; }
- (void) set_skip_taskbar: (BOOL) b { skip_taskbar = b; }
- (void) set_fullscreen: (BOOL) b { fullscreen = b; }
- (void) set_above: (BOOL) b { above = b; }
- (void) set_below: (BOOL) b { below = b; }

- (void) set_user_time: (Time) time { user_time = time; }
- (Time) user_time { return user_time; }

- (unsigned int) decorations { return decorations; }
- (void) set_decorations: (unsigned int) i { decorations = i; }
- (BOOL) undecorated { return undecorated; }
- (void) set_undecorated: (BOOL) b { undecorated = b; }
- (unsigned int) functions { return functions; }
- (void) set_functions: (unsigned int) i { functions = i; }

- (NSArray *) icons { return icons; }
- (void) removeAllIcons { [icons removeAllObjects]; }
- (void) addIcon: (AZClientIcon *) icon { [icons addObject: icon]; }

- (BOOL) isGNUstepDocumentEdited { return isGNUstepDocumentEdited; }

- (id) init
{
	self = [super init];
	icons = [[NSMutableArray alloc] init];
	transients = [[NSMutableArray alloc] init];
	opacity = 0xffffffff;
	return self;
}

- (void) dealloc
{
	DESTROY(transients);
	DESTROY(icons);
	DESTROY(group);
	DESTROY(frame);
	DESTROY(title);
	DESTROY(icon_title);
	DESTROY(name);
	DESTROY(class);
	DESTROY(role);
	DESTROY(client_machine);
	DESTROY(sm_client_id);
	[super dealloc];
}

/* Only used by categories */

- (void) changeAllowedActions
{
    unsigned long actions[9];
    int num = 0;

    /* desktop windows are kept on all desktops */
    if (type != OB_CLIENT_TYPE_DESKTOP)
        actions[num++] = prop_atoms.net_wm_action_change_desktop;

    if (functions & OB_CLIENT_FUNC_SHADE)
        actions[num++] = prop_atoms.net_wm_action_shade;
    if (functions & OB_CLIENT_FUNC_CLOSE)
        actions[num++] = prop_atoms.net_wm_action_close;
    if (functions & OB_CLIENT_FUNC_MOVE)
        actions[num++] = prop_atoms.net_wm_action_move;
    if (functions & OB_CLIENT_FUNC_ICONIFY)
        actions[num++] = prop_atoms.net_wm_action_minimize;
    if (functions & OB_CLIENT_FUNC_RESIZE)
        actions[num++] = prop_atoms.net_wm_action_resize;
    if (functions & OB_CLIENT_FUNC_FULLSCREEN)
        actions[num++] = prop_atoms.net_wm_action_fullscreen;
    if (functions & OB_CLIENT_FUNC_MAXIMIZE) {
        actions[num++] = prop_atoms.net_wm_action_maximize_horz;
        actions[num++] = prop_atoms.net_wm_action_maximize_vert;
    }

    PROP_SETA32(window, net_wm_allowed_actions, atom, actions, num);

    /* make sure the window isn't breaking any rules now */

    if (!(functions & OB_CLIENT_FUNC_SHADE) && shaded) {
        if (frame) [self shade: NO];
        else shaded = NO;
    }
    if (!(functions & OB_CLIENT_FUNC_ICONIFY) && iconic) {
        if (frame) 
	  [self iconify: NO currentDesktop: YES];
        else iconic = NO;
    }
    if (!(functions & OB_CLIENT_FUNC_FULLSCREEN) && fullscreen) {
        if (frame) 
	  [self fullscreen: NO];
        else 
	  fullscreen = NO;
    }
    if (!(functions & OB_CLIENT_FUNC_MAXIMIZE) && (max_horz || max_vert)) {
        if (frame) 
	{
          [self maximize: NO direction: 0];
	}
	else 
	{
	  max_vert = NO;
	  max_horz = NO;
	}
    }
}

- (Window_InternalType) windowType { return Window_Client; }
- (int) windowLayer { return layer; }
- (Window) windowTop { return [[self frame] window]; }

@end

AZClient *AZUnderPointer()
{
    int x, y;
    AZClient *ret = nil;
    int i, count = [[AZStacking stacking] count];

    if ([[AZScreen defaultScreen] pointerPosAtX: &x y: &y]) {
	for (i = 0; i < count; i++) {
	    id <AZWindow> temp = [[AZStacking stacking] windowAtIndex: i];
            if (WINDOW_IS_CLIENT(temp)) {
                AZClient *c = temp;
                if ([[c frame] visible] &&
                    RECT_CONTAINS([[c frame] area], x, y)) {
                    ret = c;
                    break;
                }
            }
        }
    }
    if (ret) 
	return ret;
    else
    	return nil;
}

@implementation AZClientIcon
- (int) width { return width; }
- (void) setWidth: (int) w { width = w; }
- (int) height { return height; }
- (void) setHeight: (int) h { height = h; }
- (RrPixel32 *) data { return data; }
- (void) setData: (RrPixel32 *) d { data = d; }

- (void) dealloc
{
  if (data) {
    free(data);
    data = NULL;
  }
  [super dealloc];
}
@end

@implementation AZClient (AZPrivate)

- (void) getStartupId
{
    NSString *data = nil;
    DESTROY(startup_id);

    if (!(PROP_GETS(window, net_startup_id, utf8, &data)))
    {
        if (group)
	{
            PROP_GETS([group leader], net_startup_id, utf8, &data);
	}
    }
    if (data) {
      ASSIGNCOPY(startup_id, data);
    }
}

- (void) getArea
{
    XWindowAttributes wattrib;
    Status ret;
  
    ret = XGetWindowAttributes(ob_display, window, &wattrib);
    NSAssert(ret != BadWindow, @"Bad Window");

    RECT_SET(area, wattrib.x, wattrib.y, wattrib.width, wattrib.height);
    POINT_SET(root_pos, wattrib.x, wattrib.y);
    border_width =  wattrib.border_width;
}

- (void) getDesktop
{
    AZScreen *screen = [AZScreen defaultScreen];
    unsigned int num_desktops = [screen numberOfDesktops];
    unsigned long d = num_desktops; /* an always-invalid value */

    if (PROP_GET32(window, net_wm_desktop, cardinal, &d)) {
        if (d >= num_desktops && d != DESKTOP_ALL)
            desktop = num_desktops - 1;
        else
            desktop = d;
    } else {
        BOOL trdesk = NO;

        if (transient_for) {
            if (transient_for != OB_TRAN_GROUP) {
                desktop = [transient_for desktop];
                trdesk = YES;
            } else {
		int i, count = [[group members] count];
		for (i = 0; i < count; i++) {
		  AZClient *data = [group memberAtIndex: i];
		  if (data != self && (![data transient_for])) {
		    desktop = [data desktop];
		    trdesk = YES;
		    break;
		  }
		}
            }
        }
        if (!trdesk) {
            /* try get from the startup-notification protocol */
            AZStartupHandler *handler = [AZStartupHandler defaultHandler];
	    if ([handler getDesktop: &desktop
			 forIdentifier: (char*)[startup_id UTF8String]])
	    {
                if (desktop >= num_desktops &&
                    desktop != DESKTOP_ALL)
                    desktop = num_desktops - 1;
            } else
                /* defaults to the current desktop */
                desktop = [screen desktop];
        }
    }
    if (desktop != d) {
        /* set the desktop hint, to make sure that it always exists */
        PROP_SET32(window, net_wm_desktop, cardinal, desktop);
    }
}

- (void) getState
{
    unsigned long *state;
    unsigned int num;
  
    if (PROP_GETA32(window, net_wm_state, atom, &state, &num)) {
        unsigned long i;
        for (i = 0; i < num; ++i) {
            if (state[i] == prop_atoms.net_wm_state_modal)
                modal = YES;
            else if (state[i] == prop_atoms.net_wm_state_shaded)
                shaded = YES;
            else if (state[i] == prop_atoms.net_wm_state_hidden)
                iconic = YES;
            else if (state[i] == prop_atoms.net_wm_state_skip_taskbar)
                skip_taskbar = YES;
            else if (state[i] == prop_atoms.net_wm_state_skip_pager)
                skip_pager = YES;
            else if (state[i] == prop_atoms.net_wm_state_fullscreen)
                fullscreen = YES;
            else if (state[i] == prop_atoms.net_wm_state_maximized_vert)
                max_vert = YES;
            else if (state[i] == prop_atoms.net_wm_state_maximized_horz)
                max_horz = YES;
            else if (state[i] == prop_atoms.net_wm_state_above)
                above = YES;
            else if (state[i] == prop_atoms.net_wm_state_below)
                below = YES;
            else if (state[i] == prop_atoms.net_wm_state_demands_attention)
                demands_attention = YES;
            else if (state[i] == prop_atoms.ob_wm_state_undecorated)
                undecorated = YES;
        }

        free(state);
    }
}

- (void) getLayer
{
    if (!(above || below)) {
        if (group) {
            /* apply stuff from the group */
            int ly= -2;
	    int i;
	    NSArray *members = [[self group] members];
	    for (i = 0; i < [members count]; i++)
	    {
	      AZClient *c = [members objectAtIndex: i];
	      if ((c != self) && ![self searchTransient: c] &&
		  [self normal] && [c normal])
	      {
                    ly = MAX(ly, ([c above] ? 1 : ([c below] ? -1 : 0)));
              }
            }
            switch (ly) {
            case -1:
                below = YES;
                break;
            case -2:
            case 0:
                break;
            case 1:
                above = YES;
                break;
            default:
		NSLog(@"Internal Error: getLayer shouldn't read here");
                break;
            }
        }
    }
}


- (void) getShaped
{
    shaped = NO;
#ifdef   SHAPE
    if (extensions_shape) {
        int foo;
        unsigned int ufoo;
        int s;

        XShapeSelectInput(ob_display, window, ShapeNotifyMask);

        XShapeQueryExtents(ob_display, window, &s, &foo,
                           &foo, &ufoo, &ufoo, &foo, &foo, &foo, &ufoo,
                           &ufoo);
        shaped = (s != 0);
    }
#endif
}

- (void) getMwmHints
{
    unsigned int num;
    unsigned long *hints;

    mwmhints.flags = 0; /* default to none */

    if (PROP_GETA32(window, motif_wm_hints, motif_wm_hints,
                    &hints, &num)) {
        if (num >= OB_MWM_ELEMENTS) {
            mwmhints.flags = hints[0];
            mwmhints.functions = hints[1];
            mwmhints.decorations = hints[2];
        }
        free(hints);
    }
}

- (void) getGravity
{
    XWindowAttributes wattrib;
    Status ret;

    ret = XGetWindowAttributes(ob_display, window, &wattrib);
    NSAssert((ret != BadWindow), @"Bad window");
    gravity = wattrib.win_gravity;
}


- (ObStackingLayer) calcStackingLayer
{
    ObStackingLayer l;

    if (fullscreen && ([self focused] || [self searchFocusTree]))
        l = OB_STACKING_LAYER_FULLSCREEN;
    else if (type == OB_CLIENT_TYPE_DESKTOP)
        l = OB_STACKING_LAYER_DESKTOP;
    else if (type == OB_CLIENT_TYPE_DOCK) {
        if (below) l = OB_STACKING_LAYER_NORMAL;
        else l = OB_STACKING_LAYER_ABOVE;
    }
    else if (above) l = OB_STACKING_LAYER_ABOVE;
    else if (below) l = OB_STACKING_LAYER_BELOW;
    else l = OB_STACKING_LAYER_NORMAL;

    if ([self isGNUstep])
    {
      if (gnustep_attr.flags & GSWindowLevelAttr) {
        /* use window level */
	l = gnustep_attr.window_level + OB_STACKING_LAYER_NORMAL;
      }
    }

    return l;
}

- (void) calcLayerRecursiveWithOriginal: (AZClient *)orig
        stackingLayer: (ObStackingLayer) min raised: (BOOL) raised
{
    ObStackingLayer old, own;
    AZStacking *stacking = [AZStacking stacking];

    old = layer;
    own = [self calcStackingLayer];
    layer = MAX(own, min);

    int j, jcount = [transients count];
    AZClient *temp = nil;
    for (j = 0; j < jcount; j++) {
	temp = [transients objectAtIndex: j];
	[temp calcLayerRecursiveWithOriginal: orig
		stackingLayer: layer raised: (raised ? raised : layer != old)];
    }

    if (!raised && layer != old)
        if ([orig frame]) { /* only restack if the original window is managed */
            [stacking removeWindow: self];
            [stacking addWindow: self];
        }
}

- (void) iconifyRecursive: (BOOL) _iconic currentDesktop: (BOOL) curdesk
{
    BOOL changed = NO;


    if (iconic != _iconic) {
	    NSDebugLLog(@"Client", 
		            @"%sconifying window: 0x%lx\n", 
		            (_iconic ? "I" : "Uni"), window);

        if (_iconic) {
            if (functions & OB_CLIENT_FUNC_ICONIFY) {
		iconic = _iconic;

                /* update the focus lists.. iconic windows go to the bottom of
                   the list, put the new iconic window at the 'top of the
                   bottom'. */
		[[AZFocusManager defaultManager] focusOrderToTop: self];

                changed = YES;
            }
        } else {
	    iconic = _iconic;

            if (curdesk)
		[self setDesktop: [[AZScreen defaultScreen] desktop]
			     hide: NO];

            /* this puts it after the current focused window */
	    AZFocusManager *fManager = [AZFocusManager defaultManager];
	    [fManager focusOrderRemove: self];
	    [fManager focusOrderAdd: self];

            changed = YES;
        }
    }

    if (changed) {
	[self changeState];
	[self showhide];
	if (STRUT_EXISTS([self strut]))
	  [[AZScreen defaultScreen] updateAreas];
    }

    /* iconify all direct transients */
    int j, jcount = [transients count];
    AZClient *temp = nil;
    for (j = 0; j < jcount; j++) {
        temp = [transients objectAtIndex: j];
	if (temp != self) {
	    if ([self hasDirectChild: temp])
	    {
		[temp iconifyRecursive: _iconic currentDesktop: curdesk];
	    }
	}
    }
}

- (void) setDesktopRecursive: (unsigned int) target
                        hide: (BOOL) donthide 
{
    unsigned int old;
    AZFocusManager *fManager = [AZFocusManager defaultManager];

    if (target != desktop) {

        NSDebugLLog(@"Client", @"Setting desktop %u\n", target+1);

        NSAssert((target < [[AZScreen defaultScreen] numberOfDesktops] || target == DESKTOP_ALL), @"Desktop out of range");

        /* remove from the old desktop(s) */
	[fManager focusOrderRemove: self];

        old = desktop;
	desktop = target;
        PROP_SET32(window, net_wm_desktop, cardinal, target);
        /* the frame can display the current desktop state */
	[frame adjustState];
        /* 'move' the window to the new desktop */
        if (!donthide)
	    [self showhide];
        /* raise if it was not already on the desktop */
        if (old != DESKTOP_ALL)
	    [self raise];
	if (STRUT_EXISTS([self strut]))
	  [[AZScreen defaultScreen] updateAreas];

        /* add to the new desktop(s) */
        if (config_focus_new)
	    [fManager focusOrderToTop: self];
        else
	    [fManager focusOrderToBottom: self];
    }

    /* move all transients */
    int j, jcount = [transients count];
    AZClient *temp = nil;
    for (j = 0; j < jcount; j++) 
    {
        temp = [transients objectAtIndex: j];
	if (temp != self) 
	{
	    if ([self hasDirectChild: temp])
	    {
	        [temp setDesktopRecursive: target hide: donthide];
	    }
	}
    }
}

- (AZClientIcon *) iconRecursiveWithWidth: (int) w height: (int) h
{
    unsigned int i;
    /* si is the smallest image >= req */
    /* li is the largest image < req */
    unsigned long size, smallest = 0xffffffff, largest = 0, si = 0, li = 0;

    if ([icons count] == 0) {
	// No icon
        AZClientIcon *parent = nil;

        if (transient_for) {
            if (transient_for != OB_TRAN_GROUP)
	        parent = [[self transient_for] iconRecursiveWithWidth: w height: h];
            else {
	        int i, count = [[group members] count];
		for (i = 0; i < count; i++) {
		  AZClient *c = [group memberAtIndex: i];
                    if (c != self && ![c transient_for]) {
                        if ((parent = [c iconRecursiveWithWidth: w height: h]))
                            break;
                    }
                }
            }
        }
        
        return parent;
    }

    int count = [icons count];
    for (i = 0; i < count; ++i) {
	AZClientIcon *icon = [icons objectAtIndex: i];
	size = [icon width] * [icon height];
        if (size < smallest && size >= (unsigned)(w * h)) {
            smallest = size;
            si = i;
        }
        if (size > largest && size <= (unsigned)(w * h)) {
            largest = size;
            li = i;
        }
    }
    if (largest == 0) /* didnt find one smaller than the requested size */
    {
	return [icons objectAtIndex: si];
    }
    return [icons objectAtIndex: li];
}

- (void) getClientMachine
{
    NSString *data = nil;
    char localhost[128];

    DESTROY(client_machine);

    if (PROP_GETS(window, wm_client_machine, locale, &data)) {
        gethostname(localhost, 127);
        localhost[127] = '\0';
        NSString *l = [NSString stringWithUTF8String: localhost];
        /*if (strcmp(localhost, data))*/
        if ([data isEqualToString: l] == NO)
        {
            ASSIGN(client_machine, data);
        }
    }
}

@end

