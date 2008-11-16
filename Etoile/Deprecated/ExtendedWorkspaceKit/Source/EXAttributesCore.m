/*
	EXAttributesCore.m

	Attributes related semi abstract class which specifies the class cluster
	interface for their support/storage

	Copyright (C) 2004 Quentin Mathe <qmathe@club-internet.fr>

	Author:   Quentin Mathe <qmathe@club-internet.fr>
	Created:  August 2004

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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "EXBasicFSAttributesExtracter.h"
#import "EXContext.h"
#import "ExtendedWorkspaceConfig.h"
#import "EXRDFAttributesCore.h"
#import "EXVFS.h"
#import "EXWorkspace.h"
#import "EXAttributesCore.h"

static EXAttributesCore *sharedInstance;

@interface EXContext (Private)
- (void) _setAttributes: (NSMutableDictionary *)dict;
@end

@implementation EXAttributesCore

/*
+ (void) initialize
{
	if (self == [EXAttributesCore class])
	{
	
	}
}
 */
 
// Basic methods

+ (EXAttributesCore *) sharedInstance
{
  	if (sharedInstance == nil)
    	{
      		if (AttributesBackend == RDFBerkeleyDB)
        	{
          		sharedInstance = [EXRDFAttributesCore alloc];
        	}
      		else
        	{
          		sharedInstance = [EXAttributesCore alloc];
	    	}     
      		sharedInstance = [sharedInstance init];
    	}
    
  	return sharedInstance;      
}

- (id) init
{
  if (sharedInstance != self)
    {
      RELEASE(self);
      return RETAIN(sharedInstance);
    }
  
  if ((self = [super init])  != nil)
    {
      _vfs = [EXVFS sharedInstance];
    }
  
  return self;
}

- (void) loadAttributesForContext: (EXContext *)context
{
    NSMutableDictionary *dict = [self storedAttributesForContext: context];
    
    if (dict == nil)
    {
        dict = [self extractAttributesForContext: context];
        [context _setAttributes: dict];
        [self storeAttributesForContext: context];
    }
}

- (NSMutableDictionary *) storedAttributesForContext: (EXContext *)context
{
    return nil; // Must be overriden in a subclass, example RDFAttributesCore
}

- (NSMutableDictionary *) extractAttributesForContext: (EXContext *)context
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity: 30];
    EXBasicFSAttributesExtracter *basicExtracter = 
        [EXBasicFSAttributesExtracter sharedInstance];
    
    [dict addEntriesFromDictionary: [basicExtracter attributesForContext:  context]];
    // More to come here EXIF, XML etc.
    
    return dict;
}

- (void) storeAttributesForContext: (EXContext *)context
{
    // Must be overriden in a subclass, example RDFAttributesCore
}

@end