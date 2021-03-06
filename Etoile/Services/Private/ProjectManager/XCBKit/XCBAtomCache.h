/**
 * Étoilé ProjectManager - XCBAtomCache.h
 *
 * Copyright (C) 2009 David Chisnall
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 **/
#import <Foundation/Foundation.h>
#import <xcb/xcb.h>


@interface XCBAtomCache : NSObject {
@protected
	// atom name (atoms with pending requests) 
	NSMutableSet *inRequestAtoms;
	// Cookie => atom name (cookies of pending atom requests)
	NSMutableDictionary *requestedAtoms;
	// atom name => xcb_atom_t (fetched atoms map)
	NSMutableDictionary *fetchedAtoms;

	// xcb_atom_t => atom_name (reverse fetched atoms map)
	NSMutableDictionary *fetchedAtomNames;
}
+ (XCBAtomCache*)sharedInstance;

/**
  * Returns the atom with the specified name. 
  * If the atom has not been cached, it will
  * synchronously interned and cached before
  * returning from this method. 
  */
- (xcb_atom_t)atomNamed: (NSString*)aString;

/**
  * Get the name of the specified atom. If
  * the name is not in the cache, it will be
  * synchronously fetched.
  */
- (NSString*)nameForAtom: (xcb_atom_t)atom;

/**
  * Asynchronously cache a number of atoms.
  * Call -waitOnPendingAtomRequests to 
  * synchronously cache all pending atom
  * requests.
  */
- (void)cacheAtoms: (NSArray*)atoms;
- (void)waitOnPendingAtomRequests;
@end

/**
  * XCBAtom is a helper class to assist with storing
  * atoms in arrays and other GNUstep data structures
  */
@interface NSValue (XCBAtom)
+ (NSValue*)valueWithXCBAtom: (xcb_atom_t)atom;
- (xcb_atom_t)xcbAtomValue;
@end
