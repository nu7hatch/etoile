#
#	GNUmakefile
#
#	Makefile for Developer Services
#
#	Copyright (C) 2005 Quentin Mathe <qmathe@club-internet.fr>
#
#	This Makefile is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License
#	as published by the Free Software Foundation; either version 2
#	of the License, or (at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
#	See the GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to:
#
#		Free Software Foundation, Inc.
#		59 Temple Place - Suite 330
#		Boston, MA  02111-1307, USA
#

PACKAGE_NAME = DeveloperServices

include $(GNUSTEP_MAKEFILES)/common.make

#
# Projects (listed by dependency order, then alphabetical order)
#

export unittests ?= no


#
# Projects (listed by dependency order, then alphabetical order)
#

ifeq ($(unittests), yes)
	SUBPROJECTS = UnitTests
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make
