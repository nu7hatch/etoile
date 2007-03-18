
include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_OBJCFLAGS = -Wno-import

BUNDLE_NAME = RSSKitTests
RSSKitTests_OBJC_FILES= RSSKitTests.m RDFTests.m RSSTests.m
RSSKitTests_HEADER_FILES = RSSKitTests.h RDFTests.h RSSTests.h

ifeq ($(FOUNDATION_LIB), apple)
	RSSKitTests_OBJC_LIBS += -framework UnitKit -lRSSKit
else
	RSSKitTests_OBJC_LIBS = -lUnitKit -lRSSKit
endif

RSSKitTests_RESOURCE_FILES = 

TOOL_NAME = rss_parser

rss_parser_OBJC_FILES = FeedParser.m
rss_parser_OBJC_LIBS = -lRSSKit

include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/tool.make

 
