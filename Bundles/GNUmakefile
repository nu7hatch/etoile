PACKAGE_NAME = Bundles

include $(GNUSTEP_MAKEFILES)/common.make

#
# Release options
# 

export camaelon = no
export wildmenus = no

#
# Variables check
#

export etoile ?= yes

ifeq ($(etoile), no)

    export desktop-base ?= yes
    export etoile-extensions ?= no

endif

ifeq ($(etoile), yes)

    export desktop-base ?= yes
    export etoile-extensions ?= yes

endif

export desktop-base ?= yes

ifeq ($(desktop-base), yes)

    export camaelon ?= yes
    export wildmenus ?= yes

endif

export etoile-extensions ?= yes

ifeq ($(etoile-extensions), yes)

    export sqliteclient ?= yes

endif

#
# Subprojects choice
#

ifeq ($(camaelon), yes)
    SUBPROJECTS += Camaelon
endif

ifeq ($(sqliteclient), yes)
  ifeq ($(FOUNDATION_LIB), apple) # Cocoa only module
    SUBPROJECTS += SQLiteClient
  endif
endif

ifeq ($(wildmenus), yes)
    SUBPROJECTS += WildMenus
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make
