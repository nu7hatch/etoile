/* -*- indent-tabs-mode: nil; tab-width: 4; c-basic-offset: 4; -*-

   AZMenuManager.m for the Azalea window manager
   Copyright (c) 2006        Yen-Ju Chen

   menu.c for the Openbox window manager
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

#import "AZMenuManager.h"
#import "AZScreen.h"
#import "AZClient.h"
#import "AZClientManager.h"
#import "AZMenuFrame.h"
#import "AZKeyboardHandler.h"
#import "openbox.h"
#import "config.h"
#import "geom.h"
#import "misc.h"
#import "client_menu.h"
#import "client_list_menu.h"
#import "parse.h"
#import "action.h"

typedef struct _ObMenuParseState ObMenuParseState;

struct _ObMenuParseState
{
    AZMenu *parent;
};

static AZParser *menu_parse_inst = nil;
static ObMenuParseState menu_parse_state;

//static void menu_destroy_hash_value(AZMenu *self);
static void parse_menu_item(AZParser *parser, xmlDocPtr doc, xmlNodePtr node,
                            void * data);
static void parse_menu_separator(AZParser *parser,
                                 xmlDocPtr doc, xmlNodePtr node,
                                 void * data);
static void parse_menu(AZParser *parser, xmlDocPtr doc, xmlNodePtr node,
                       void *data);

static void parse_menu_item(AZParser *parser, xmlDocPtr doc, xmlNodePtr node,
                            void * data)
{
    ObMenuParseState *state = data;
    NSString *label;
    
    if (state->parent) {
        if (parse_attr_string("label", node, &label)) {
	    NSMutableArray *acts = [[NSMutableArray alloc] init];

            for (node = node->children; node; node = node->next)
                if (!xmlStrcasecmp(node->name, (const xmlChar*) "action")) {
                    AZAction *a = action_parse
                        (doc, node, OB_USER_ACTION_MENU_SELECTION);
                    if (a)
			[acts addObject: a];
                }
	    [state->parent addNormalMenuEntry: -1 label: label actions: acts];
	    DESTROY(acts);
        }
    }
}

static void parse_menu_separator(AZParser *parser,
                                 xmlDocPtr doc, xmlNodePtr node,
                                 void * data)
{
    ObMenuParseState *state = data;

    if (state->parent)
	[state->parent addSeparatorMenuEntry: -1];
}

static void parse_menu(AZParser *parser, xmlDocPtr doc, xmlNodePtr node,
                       void * data)
{
    ObMenuParseState *state = data;
    NSString *name = nil, *title = nil, *script = nil;
    AZMenu *menu;

    if (!parse_attr_string("id", node, &name))
	return;

    if (![[AZMenuManager defaultManager] menuWithName: name]) {
        if (!parse_attr_string("label", node, &title))
	    return;

        if ((menu = [[AZMenu alloc] initWithName: name title: title])) {
            if (parse_attr_string("execute", node, &script)) {
                [menu set_execute: [script stringByExpandingTildeInPath]];
            } else {
                AZMenu *old;

                old = state->parent;
                state->parent = menu;
		[parser parseDocument: doc node: node->children];
                state->parent = old;
            }
	    [[AZMenuManager defaultManager] registerMenu: menu];
	    DESTROY(menu);
        }
    }

    if (state->parent)
	[state->parent addSubmenuMenuEntry: -1 submenu: name];
}

#if 0
static void menu_destroy_hash_value(AZMenu *self)
{
    /* make sure its not visible */
    {
	NSArray *visibles = [AZMenuFrame visibleFrames];
	int i, count = [visibles count];
        AZMenuFrame *f;

	for (i = 0; i < count; i++) {
	    f = [visibles objectAtIndex: i];
            if ([f menu] == self)
		AZMenuFrameHideAll();
        }
    }

    DESTROY(self);
}
#endif

static AZMenuManager *sharedInstance;

@implementation AZMenuManager

+ (AZMenuManager *) defaultManager
{
  if (sharedInstance == nil)
    sharedInstance = [[AZMenuManager alloc] init];
  return sharedInstance; 
}

- (void) startup: (BOOL) reconfig
{
    xmlDocPtr doc;
    xmlNodePtr node;
    BOOL loaded = NO;
    int i, count;

    menu_hash = [[NSMutableDictionary alloc] init];

    client_list_menu_startup(reconfig);
    client_menu_startup();

    menu_parse_inst = [[AZParser alloc] init];

    menu_parse_state.parent = nil;
    [menu_parse_inst registerTag: @"menu" callback: parse_menu 
	                 data: &menu_parse_state];
    [menu_parse_inst registerTag: @"item" callback: parse_menu_item 
	                 data: &menu_parse_state];
    [menu_parse_inst registerTag: @"separator" callback: parse_menu_separator
	                 data: &menu_parse_state];

    count = [config_menu_files count];
    for (i = 0; i < count; i++) {
	if (parse_load_menu([config_menu_files objectAtIndex: i],
				&doc, &node))
	{
            loaded = YES;
	    [menu_parse_inst parseDocument: doc node: node->children];
            xmlFreeDoc(doc);
        }
    }
    if (!loaded) {
        if (parse_load_menu(@"menu.xml", &doc, &node)) {
	    [menu_parse_inst parseDocument: doc node: node->children];
            xmlFreeDoc(doc);
        }
    }
    
    NSAssert(menu_parse_state.parent == nil, @"menu_parse_state.parent is not nil");
}

- (void) shutdown: (BOOL) reconfig
{
    DESTROY(menu_parse_inst);
    
    client_list_menu_shutdown(reconfig);

    AZMenuFrameHideAll();
    DESTROY(menu_hash);
}

- (AZMenu *) menuWithName: (NSString *) name
{
    AZMenu *menu = nil;

    NSAssert(name != nil, @"menuWithName: cannot take 'nil'.");

    if (!(menu = [menu_hash objectForKey: name]))
	NSLog(@"Warning: Attemped to access menu '%@' but it does not exist.", name);
    return menu;
}  

- (void) removeMenu: (AZMenu *) menu
{
  /* make sure its not visible */
  {
    NSArray *visibles = [AZMenuFrame visibleFrames];
    int i, count = [visibles count];
    AZMenuFrame *f;

    for (i = 0; i < count; i++) {
      f = [visibles objectAtIndex: i];
      if ([f menu] == menu)
        AZMenuFrameHideAll();
    }
  }

  [menu_hash removeObjectForKey: [menu name]];
}

- (void) showMenu: (NSString *) name x: (int) x y: (int) y 
	   client: (AZClient *) client
{
    AZMenu *menu;
    AZMenuFrame *frame;

    if (!(menu = [self menuWithName: name])
	|| [[AZKeyboardHandler defaultHandler] interactivelyGrabbed]) return;

    /* if the requested menu is already the top visible menu, then don't
       bother */
    NSArray *visibles = [AZMenuFrame visibleFrames];
    if ([visibles count]) {
	frame = [visibles objectAtIndex: 0];
        if ([frame menu] == menu)
            return;
    }

    AZMenuFrameHideAll();

    frame = [[AZMenuFrame alloc] initWithMenu: menu client: client];
    if (![frame showTopMenuAtX: x y: y])
	DESTROY(frame);
#if 0 
    /* I don't think it is a good idea to select the first non-submenu 
     * automatically because it is not a consistent user interface behavior.
     */
    else if ([[frame entries] count]) {
      AZMenuEntryFrame *e = [[frame entries] objectAtIndex: 0];
      if ([[e entry] type] == OB_MENU_ENTRY_TYPE_NORMAL &&
	   [(AZNormalMenuEntry*)[e entry] enabled]) {
	[frame selectNext];
      }
    }
#endif
}

- (void) registerMenu: (AZMenu *) menu
{
  AZMenu *m = nil;
  if ((m = [menu_hash objectForKey: [menu name]]))  {
    [self removeMenu: m];
  }
  [menu_hash setObject: menu forKey: [menu name]];
}

@end

