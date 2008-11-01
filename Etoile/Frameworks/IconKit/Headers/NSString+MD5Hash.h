//
//  NSString+MD5Hash.h
//  Uses code by L. Peter Deutsch <ghost@aladdin.com>
//  Poured into an NSString category by Denis Defreyne <amonre@amonre.org>
//
//  Copyright (c) 2004 amon-re. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
  Copyright (C) 1999, 2002 Aladdin Enterprises.  All rights reserved.

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  L. Peter Deutsch
  ghost@aladdin.com
 */

@interface NSString (MD5Hash)

- (NSString *)md5Hash;

@end
