/*
	IKIconTheme.m

	IKIconTheme class provides icon theme support (finding, loading icon 
	theme bundles and switching between them)

	Copyright (C) 2007 Quentin Mathe <qmathe@club-internet.fr>

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  February 2007

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

#import <IconKit/IKIconTheme.h>
#import <UnitKit/UnitKit.h>


/*
 * Private variables and constants
 */

#define IconThemePathComponent @"Themes/Icon"
#define IconThemeExt @"icontheme"

/* All the themes found by IKIconTheme on load and keyed by their bundle
   name */
static NSMutableDictionary *themes = nil;
static IKIconTheme *activeTheme = nil;

/*
 * Private methods
 */

@interface IKIconTheme (IconKitPrivate)
+ (NSDictionary *) findAllThemeBundles;
+ (NSDictionary *) themeBundlesInDirectory: (NSString *)themeFolder;
+ (IKIconTheme *) loadThemeBundleAtPath: (NSString *)themePath;

- (NSString *) path;

- (void) loadIdentifierMappingList;

@end

/*
 * Main implementation
 */

@implementation IKIconTheme

+ (void) initialize
{
	if (self == [IKIconTheme class])
	{
		themes = [[NSMutableDictionary alloc] init];
	}
}

+ (void) testFindAllThemeBundles
{
	NSDictionary *themeBundlePaths = [IKIconTheme findAllThemeBundles];

	UKNotNil(themeBundlePaths);
	// NOTE: The following test will fail if no theme bundle has been installed 
	// in standard locations.
	UKTrue([themeBundlePaths count] >= 1);
}

+ (NSDictionary *) findAllThemeBundles
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
		NSAllDomainsMask, YES);
	NSEnumerator *e = [paths objectEnumerator];
	NSString *parentPath = nil;
	NSMutableDictionary *allThemeBundlePaths = [NSMutableDictionary dictionary];

	while ((parentPath = [e nextObject]) != nil)
	{
		NSString *themeFolder = [parentPath 
			stringByAppendingPathComponent: IconThemePathComponent];
		NSDictionary *themeBundlePaths = [IKIconTheme 
			themeBundlesInDirectory: themeFolder];

		[allThemeBundlePaths addEntriesFromDictionary: themeBundlePaths];
	}

	return allThemeBundlePaths;
}

+ (void) testThemeBundlesInDirectory
{
	NSString *iconKitDir = [[NSFileManager defaultManager] currentDirectoryPath];
	NSDictionary *themeBundlePaths = 
		[IKIconTheme themeBundlesInDirectory: iconKitDir];
	NSBundle *themeBundle = nil;

	NSLog(@"Found %@ as IconKit directory", iconKitDir);

	UKNotNil(themeBundlePaths);
	UKTrue([themeBundlePaths count] >= 1);

	themeBundle = [themeBundlePaths objectForKey: @"test"];
	UKNotNil(themeBundle);
}

+ (NSDictionary *) themeBundlesInDirectory: (NSString *)themeFolder
{
	NSParameterAssert(themeFolder != nil);

	NSDirectoryEnumerator *e = 
		[[NSFileManager defaultManager] enumeratorAtPath: themeFolder];
	NSString *themeBundleName = nil;
	NSMutableDictionary *themeBundlePaths = [NSMutableDictionary dictionary];

	NSAssert1(e != nil, @"No directory found at path %@", themeFolder);

	NSDebugLLog(@"IconKit", @"Find themes in directory %@", themeFolder);

	while ((themeBundleName = [e nextObject]) != nil )
	{
		/* Ignore subfolders and don't search in packages */
		if ([[[e fileAttributes] fileType] isEqual: NSFileTypeDirectory])
			[e skipDescendents]; 

		/* Skip invisible files */
		if ([themeBundleName characterAtIndex: 0] == '.')
			continue;

		/* Only process ones that have the right suffix */
		if ([[themeBundleName pathExtension] isEqual: IconThemeExt] == NO)
			continue;
		
		NSDebugLLog(@"IconKit", @"Found theme %@ in directory %@", 
			themeBundleName, themeFolder);
		
		NS_DURING
			/* Get path, bundle and display name */
			NSString *themePath = [themeFolder 
				stringByAppendingPathComponent: themeBundleName];

			[themeBundlePaths setObject: themePath 
				forKey: [themeBundleName stringByDeletingPathExtension]];

		NS_HANDLER

			NSLog(@"Unable to list theme folder %@", localException);

		NS_ENDHANDLER
	}

	return themeBundlePaths;
}

+ (void) testLoadThemeBundleAtPath
{
	NSString *iconKitDir = [[NSFileManager defaultManager] currentDirectoryPath];
	NSString *themeBundlePath = [[IKIconTheme 
		themeBundlesInDirectory: iconKitDir] objectForKey: @"test"];
	IKIconTheme *theme = nil;

	theme = [IKIconTheme loadThemeBundleAtPath: themeBundlePath];

	UKNotNil(theme);

	UKNotNil(themes);
	UKTrue([themes count] >= 1);

	theme = [themes objectForKey: @"test"];
	UKNotNil(theme);
	UKStringsEqual([theme path], themeBundlePath);
}

+ (IKIconTheme *) loadThemeBundleAtPath: (NSString *)themePath
{
	NSParameterAssert(themePath != nil);

	NSBundle *themeBundle = [NSBundle bundleWithPath: themePath];

	if (themeBundle == nil)
	{
		NSLog(@"Found no valid bundle at path %@", themePath);
		return nil;
	}

	IKIconTheme *loadedTheme = AUTORELEASE([[IKIconTheme alloc] init]);
	NSString *identifier = [[themeBundle infoDictionary] 
		objectForKey: @"ThemeName"];

	if (identifier == nil)
		identifier = [[themeBundle infoDictionary] objectForKey: @"BundleName"];

	if (identifier == nil)
		identifier = [[themeBundle infoDictionary] objectForKey: @"CFBundleName"];

	if (identifier == nil)
	{
		identifier = [[themePath lastPathComponent] 
			stringByDeletingPathExtension];

		NSLog(@"Found no valid icon theme name in bundle infoDictionary, we \
will use theme bundle name %@", identifier);
	}

	ASSIGN(loadedTheme->_themeBundle, themeBundle);
	ASSIGN(loadedTheme->_themeName, identifier);
	[loadedTheme loadIdentifierMappingList];

	[themes setObject: loadedTheme forKey: identifier];

	return loadedTheme;
}

+ (IKIconTheme *) theme
{
	return activeTheme;
}

+ (void) setTheme: (IKIconTheme *)theme
{
	ASSIGN(activeTheme, theme);
	[activeTheme activate];
}

- (NSString *) path
{
	return [_themeBundle bundlePath];
}

- (id) initWithPath: (NSString *)path
{
	NSParameterAssert(path != nil);

	self = RETAIN([IKIconTheme loadThemeBundleAtPath: path]);

	return self;
}

- (id) initWithTheme: (NSString *)identifier
{
	NSParameterAssert(identifier != nil);

	IKIconTheme *loadedTheme = [themes objectForKey: identifier];

	if (loadedTheme != nil)
	{
		RELEASE(self);
		self = RETAIN(loadedTheme);
	}
	else
	{
		NSDictionary *themeBundlePaths = [IKIconTheme findAllThemeBundles];
		NSString *path = [themeBundlePaths objectForKey: identifier];

		if (path == nil)
		{
			NSLog(@"Found no theme bundle with identifier %@", identifier);
			return nil;
		}

		self = RETAIN([IKIconTheme loadThemeBundleAtPath: path]);

		// NOTE: We already make this check in +loadThemeBundleAtPath:
		if (_themeBundle == nil)
		{
			NSLog(@"Failed to load theme located at %@", path);
			return nil;
		}
	}

	return self;
}

- (id) initForTest
{
	NSString *path = [[NSFileManager defaultManager] currentDirectoryPath];

	//NSLog(@"%@ initForTest", self);

	path = [[path stringByAppendingPathComponent: @"test.icontheme"]
		stringByStandardizingPath];

	return [self initWithPath: path];
}

- (void) dealloc
{
	DESTROY(_specIdentifiers);
	DESTROY(_themeBundle);

	[super dealloc];
}

- (NSString *) description
{
	return [super description];

}

- (void) testLoadIdentifierMappingList
{
	[self loadIdentifierMappingList];

	UKNotNil(_specIdentifiers);
	UKStringsEqual([_specIdentifiers objectForKey: @"home"], @"Folder-Home");
	NSLog(@"Identifier mapping list loaded: %@", _specIdentifiers);
}

- (void) loadIdentifierMappingList
{
	NSString *mappingListPath = [_themeBundle 
		pathForResource: @"IdentifierMapping" ofType: @"plist"];

	NSAssert1(mappingListPath != nil, 
		@"Found no IdentifierMapping.plist file in Resources folder of %@", self);

	ASSIGN(_specIdentifiers, [[NSDictionary alloc] 
		initWithContentsOfFile: mappingListPath]);
}

- (void) testIconPathForIdentifier
{
	NSString *path = [self iconPathForIdentifier: @"folder"];
	NSArray *components = [path pathComponents];
	int lastIndex = [components count] - 1;

	UKNotNil(path);
	UKStringsEqual([components objectAtIndex: lastIndex], @"folder.png");
	UKStringsEqual([components objectAtIndex: --lastIndex], @"Resources");
	UKStringsEqual([components objectAtIndex: --lastIndex], @"test.icontheme");

	path = [self iconPathForIdentifier: @"home"];
	components = [path pathComponents];
	lastIndex = [components count] - 1;

	UKNotNil(path);
	UKStringsEqual([components objectAtIndex: lastIndex], @"Folder-Home.png");
}

- (NSString *) iconPathForIdentifier: (NSString *)iconIdentifier
{
	NSString *realIdentifier = [_specIdentifiers objectForKey: iconIdentifier];
	NSString *imageType = @"png";

	if (realIdentifier == nil)
		realIdentifier = iconIdentifier;

	return [_themeBundle pathForResource: realIdentifier ofType: imageType];
}

- (NSURL*) iconURLForIdentifier: (NSString *)iconIdentifier
{
	NSURL *iconURL = 
		[NSURL fileURLWithPath: [self iconPathForIdentifier: iconIdentifier]];

	return iconURL;
}

- (void) activate
{
	// TODO
}

- (void) deactivate
{
	// TODO
}

@end
