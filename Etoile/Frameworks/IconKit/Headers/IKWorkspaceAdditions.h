/*
	IKWorkspaceAdditions.h

	IKWorkspaceAdditions is a category to add IconKit support to NSWorkspace.

	Copyright (C) 2005 Uli Kusterer <contact@zathras.de>
	                   Quentin Mathe <qmathe@club-internet.fr>	                   

	Author:   Uli Kusterer <contact@zathras.de>
	          Quentin Mathe <qmathe@club-internet.fr>
	Date:  January 2005

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

#ifndef ICONKIT_IKWORKSPACEADDITIONS_H
#define ICONKIT_IKWORKSPACEADDITIONS_H 1

#include <AppKit/AppKit.h>


@interface NSWorkspace (IKIconAdditions)

- (NSImage *) iconForFile: (NSString *)fullPath;
- (NSImage *) iconForFiles: (NSArray *)fullPaths;
- (NSImage *) iconForFileType: (NSString *)fileType;

@end

#endif /*ICONKIT_IKWORKSPACEADDITIONS_H*/
