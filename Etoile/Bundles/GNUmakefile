PACKAGE_NAME = Bundles

include $(GNUSTEP_MAKEFILES)/common.make

#
# Variables check
#

export etoile ?= yes

ifeq ($(etoile), no)

    export desktop-base ?= yes
	#export etoile-extensions ?= no

endif

ifeq ($(etoile), yes)

    export desktop-base ?= yes
	#export etoile-extensions ?= yes

endif

export desktop-base ?= yes

ifeq ($(desktop-base), yes)

    export camaelon ?= yes
    export etoilewildmenus ?= yes
    export etoilebehavior ?= yes
    export servicemenulet ?= yes
    export volumecontrolmenulet ?= yes

endif

#export etoile-extensions ?= yes

#
# Subprojects choice
#

ifeq ($(camaelon), yes)
    SUBPROJECTS += Camaelon
endif

ifeq ($(etoilewildmenus), yes)
    SUBPROJECTS += EtoileWildMenus
endif

ifeq ($(etoilebehavior), yes)
    SUBPROJECTS += EtoileBehavior
endif

ifeq ($(servicemenulet), yes)
    SUBPROJECTS += ServiceMenulet
endif

ifeq ($(volumecontrolmenulet), yes)
    SUBPROJECTS += VolumeControlMenulet
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make
