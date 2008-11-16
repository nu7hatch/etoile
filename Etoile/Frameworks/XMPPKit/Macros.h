/*
 *  Macros.h
 *  Jabber
 *
 *  Created by David Chisnall on 02/08/2005.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

/** Macros specific to XMPPKit and EtoileXML */

#define AUTORELEASED(x) [[[x alloc] init] autorelease]
#define RETAINED(x) [[x alloc] init]

/* EtoileFoundation Macros are copied below, because XMPPKit depends 
   only on EtoileXML for now. In future, this may change. */

/**
 * Simple macro for safely initialising the superclass.
 */
#define SUPERINIT if((self = [super init]) == nil) {return nil;}
/**
 * Simple macro for safely initialising the current class.
 */
#define SELFINIT if((self = [self init]) == nil) {return nil;}
/**
 * Macro for creating dealloc methods.
 */
#define DEALLOC(x) - (void) dealloc { x ; [super dealloc]; }

@protocol MakeReleaseSelectorNotFoundErrorGoAway
- (void) release;
@end

/**
 * Cleanup function used for stack-scoped objects.
 */
__attribute__((unused)) static void ETStackAutoRelease(void* object)
{
	[*(id*)object release];
}
/**
 * Macro used to declare objects with lexical scoping.  The object will be sent
 * a release message when it goes out of scope.  
 *
 * Example:
 *
 * STACK Foo * foo = [[Foo alloc] init];
 */
#define STACK __attribute__((cleanup(ETStackAutoRelease))) 

/**
 * Set of macros providing a for each statement on collections, with IMP
 * caching.
 */
#define FOREACHI(collection,object) FOREACH(collection,object,id)

#define FOREACH(collection,object,type) FOREACHE(collection,object,type,object ## enumerator)

#define FOREACHE(collection,object,type,enumerator)\
NSEnumerator * enumerator = [collection objectEnumerator];\
type object;\
IMP next ## object ## in ## enumerator = \
[enumerator methodForSelector:@selector(nextObject)];\
while(enumerator != nil && (object = next ## object ## in ## enumerator(\
												   enumerator,\
												   @selector(nextObject))))

#define D(...) [NSDictionary dictionaryWithObjectsAndKeys:__VA_ARGS__ , nil]
#define A(...) [NSArray arrayWithObjects:__VA_ARGS__ , nil]
