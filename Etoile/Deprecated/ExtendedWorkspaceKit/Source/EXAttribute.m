/*
	EXAttribute.m

	Attributes class which implements basic attributes representation and interaction

	Copyright (C) 2004 Quentin Mathe <qmathe@club-internet.fr>

	Author:   Quentin Mathe <qmathe@club-internet.fr>
	Date:  June 2004

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
#import "EXAttribute.h"

@implementation EXAttribute


@end

/*
 * Primary attributes identifiers
 */

NSString * const EXAttributeCreationDate = @"EXAttributeCreationDate";
NSString * const EXAttributeModificationDate = @"EXAttributeModificationDate";
NSString * const EXAttributeName = @"EXAttributeName";
NSString * const EXAttributeSize = @"EXAttributeSize";
NSString * const EXAttributeFSNumber = @"EXAttributeFSNumber";
NSString * const EXAttributeFSType = @"EXAttributeFSType";
NSString * const EXAttributePosixPermissions = @"EXAttributePosixPermissions";
NSString * const EXAttributeOwnerName = @"EXAttributeOwnerName";
NSString * const EXAttributeOwnerNumber = @"EXAttributeOwnerNumber";
NSString * const EXAttributeGroupOwnerName = @"EXAttributeGroupOwnerName";
NSString * const EXAttributeGroupOwnerNumber = @"EXAttributeGroupOwnerNumber";
NSString * const EXAttributeDeviceNumber = @"EXAttributeDeviceNumber";
NSString * const EXAttributeExtension = @"EXAttributeExtension";

NSString * const EXFSTypeDirectory = @"EXFSTypeDirectory";
NSString * const EXFSTypeRegular = @"EXFSTypeRegular";
NSString * const EXFSTypeLink = @"EXFSTypeLink"; // ExtendedWorkspaceKit custom link
NSString * const EXFSTypeSymbolicLink = @"EXFSTypeSymbolicLink";
NSString * const EXFSTypeSocket = @"EXFSTypeSocket";
NSString * const EXFSTypeCharacterSpecial = @"EXFSTypeCharacterSpecial";
NSString * const EXFSTypeBlockSpecial = @"EXFSTypeBlockSpecial";
NSString * const EXFSTypeUnknown = @"EXFSTypeUnknown";