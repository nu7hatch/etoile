" This is the main class for Melodie. It coordinates CoreObject and EtoileUI,
  handles adding new songs to the library.

  Its only interaction with music playback is invoking
  'musicPlayerController playLayoutItem:start:' when a song is double-clicked. "
  
NSObject subclass: MelodieController
[
	| window  mainContainer  playlistContainer search  musicPlayerController URLTextField addURLWindow 
	  mainModel  playlistModel smartGroup ctxt |

	KnownExtensions	[
		^ {'mp3'. 'ogg'. 'aac'. 'm4a'}.
	]

	newContext [
		| defaults | 
		'Creating new object context' log.

		ctxt := COObjectContext alloc init.	
		COObjectContext setCurrentContext: ctxt.
	
		mainModel := ETPlaylist new.
		playlistModel := ETPlaylist new.

		'Registered objects: ' log.
		ctxt registeredObjects log.    

		defaults := NSUserDefaults standardUserDefaults.
		defaults setObject: (ctxt UUID stringValue) forKey: 'MellodieObjectContextUUID'.
		defaults setObject: (mainModel UUID stringValue) forKey: 'MellodieMainModelUUID'. 
		defaults setObject: (playlistModel UUID stringValue) forKey: 'MellodiePlaylistModelUUID'. 
	]

	reloadModelVariablesFromContext [
		| defaults |
		
		defaults := NSUserDefaults standardUserDefaults.
		mainModel := ctxt objectForUUID: (ETUUID UUIDWithString:
		                    (defaults stringForKey: 'MellodieMainModelUUID')).
		playlistModel := ctxt objectForUUID: (ETUUID UUIDWithString:
		                    (defaults stringForKey: 'MellodiePlaylistModelUUID')).
	]

	loadContextWithUUID: uuid [
		'Requesting object context with UUID:' log.
		uuid log.

		ctxt := COObjectContext alloc initWithUUID: (ETUUID UUIDWithString: uuid).
		COObjectContext setCurrentContext: ctxt.
	
		self reloadModelVariablesFromContext.		
			
		'Deserialized main model:' log.
		mainModel log.
		'Deserialized playlist model:' log.
		playlistModel log.
	]


	init [
		| uuid |
		'EtoileTunesController init' log.
		ETPlaylist setAutomaticallyMakeNewInstancesPersistent: 1.
		ETMusicFile setAutomaticallyMakeNewInstancesPersistent: 1.

		uuid := (NSUserDefaults standardUserDefaults stringForKey: 'MellodieObjectContextUUID').
		(uuid == nil) ifTrue: [ self newContext. ]
		             ifFalse: [ self loadContextWithUUID: uuid. ].

		^ self.
	]

	addToMainModel: obj [
		'Adding song: ' log.
		obj log.
		mainModel addMember: obj.
	]

	addPath: path [
		(self KnownExtensions containsObject: (path pathExtension))
		    ifTrue: [ self addToMainModel: (ETMusicFile alloc initWithPath: path). ]
		    ifFalse: [ 'File has unknown extension: ' log. path log. ].
	]

	addFiles: sender [
		| openPanel filename fm |

		openPanel := NSOpenPanel openPanel.
		openPanel setAllowsMultipleSelection: 0.
		openPanel setCanChooseDirectories: 1.
		openPanel runModalForTypes: (self KnownExtensions).

		filename := openPanel filenames lastObject.
		fm := NSFileManager defaultManager.
		(fm enumeratorAtPath: filename) allObjects foreach:
		    [ :subFile | self addPath: (filename stringByAppendingPathComponent: subFile). ].
		mainContainer reloadAndUpdateLayout.
	]

	undo: sender [
		ctxt undo.
		self reloadModelVariablesFromContext.
		mainContainer reloadAndUpdateLayout.
		playlistContainer reloadAndUpdateLayout.
	]

	redo: sender [	
		ctxt redo.
		self reloadModelVariablesFromContext.
		mainContainer reloadAndUpdateLayout.
		playlistContainer reloadAndUpdateLayout.
	]

	addURL: sender [
		| string |

		addURLWindow orderOut: self.
		string := URLTextField stringValue stringByAddingPercentEscapesUsingEncoding: @NSUTF8StringEncoding. 
		mainModel addMember: (ETMusicFile alloc initWithURL:(NSURL URLWithString:string)).
		mainContainer reloadAndUpdateLayout.
	]

	newPlaylist: sender [
		| newPlaylist |

		newPlaylist := ETPlaylist new.
		"Put a sample radio stream in the playlist."
		newPlaylist addMember:(ETMusicFile alloc initWithURL:
		    (NSURL URLWithString: 'http://scfire-chi0l-1.stream.aol.com/stream/1018')).
		playlistModel addMember: newPlaylist.
		playlistContainer reloadAndUpdateLayout.
	]

	awakeFromNib [
		| layout |

		layout := ETOutlineLayout layout.
	
		layout setDisplayName: 'Title' forProperty: 'kETTitleProperty'.
		layout setDisplayName: 'Artist' forProperty: 'kETArtistProperty'.
		layout setDisplayName: 'Album' forProperty: 'kETAlbumProperty'.
		layout setDisplayName: 'URL' forProperty: 'kETURLProperty'.
	
		layout setDisplayedProperties:
		    {'icon'. 'kETTitleProperty'. 'kETArtistProperty'. 'kETAlbumProperty'. 'kETURLProperty' }.

		mainContainer setSource: (mainContainer layoutItem).
		mainContainer layoutItem setRepresentedObject: mainModel.
		mainContainer setLayout: layout.
		mainContainer setHasVerticalScroller: 1.
		mainContainer setTarget: self.
		mainContainer reloadAndUpdateLayout.
		mainContainer setDoubleAction: 'doubleClickInContainer:'.

		playlistContainer setSource: (playlistContainer layoutItem).
		playlistContainer layoutItem setRepresentedObject: playlistModel.
		playlistContainer setLayout: (ETOutlineLayout layout).
		playlistContainer setHasVerticalScroller: 0.
		playlistContainer setTarget: self.
		playlistContainer setDoubleAction: 'doubleClickInContainer:'.

		search setDelegate: self.

		ScriptCenter sharedInstance enableScriptingWithObjects:
		    (NSDictionary dictionaryWithObjects: { musicPlayerController  }
		                                forKeys: { 'MusicPlayerController' }).
	]

	controlTextDidChange: notif [
		('searched for: ' stringByAppendingString: (search stringValue)) log.
		smartGroup == nil ifTrue: [ self smartGroupOn. ].
		(search stringValue length = 0)
		    ifTrue: [ 
			mainContainer layoutItem setRepresentedObject: mainModel.
		]  ifFalse: [
			mainContainer layoutItem setRepresentedObject: smartGroup.
			smartGroup setPredicate:
			    (NSPredicate predicateWithFormat: '(%K CONTAINS[cd] %@) OR (%K CONTAINS[cd] %@)'
			        argumentArray: {'kETTitleProperty' . search stringValue . 'kETAlbumProperty' . search stringValue }).
		].
		mainContainer reloadAndUpdateLayout.
	]

	smartGroupOn [
		'Turning on smart group.' log.
		smartGroup := COSmartGroup alloc init.
		smartGroup setTarget: mainModel.
		mainContainer layoutItem setRepresentedObject: smartGroup.
	]
	
	clearSearch: sender [
		search setStringValue: (NSString string). "change to ''"
		self controlTextDidChange: nil.
	]

	doubleClickInContainer: sender [
		'Got double-click on ' log.
		sender doubleClickedItem log.
		'in container: ' log.
		sender log.

		musicPlayerController playLayoutItem: (sender doubleClickedItem) start: 1.
	]
]
