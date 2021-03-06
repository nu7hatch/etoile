/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import <UnitKit/UnitKit.h>
#import "COObject.h"
#import "COGroup.h"
#import "COObjectContext.h"
#import "COObjectServer.h"
#import "COUtility.h"

#define FM [NSFileManager defaultManager]
#define TMP_URL [NSURL fileURLWithPath: [FM tempDirectory]]
#define NEW(X) (AUTORELEASE([[X alloc] init]))
#define CTXT [COObjectContext currentContext]

/* To eliminate a class name collision with other test suites */
#define SubObject SubGraphObject

@interface SubObject : COObject
@end

@interface COObjectServer (Test)
+ (void) makeNewDefaultServer;
- (NSDictionary *) cachedObjects;
@end

@interface COObjectContext (Private)
- (int) latestVersion;
@end

@interface TestGraphRollback : NSObject <UKTest>
{
	COObject *object;
	COObject *object2;
	COObject *object3;
	COGroup *group;
	COGroup *group2;
	COGroup *group3;
	int memorizedVersions[5];
}
- (void) setUpTestGraph;
@end

@implementation TestGraphRollback

- (id) initForTest
{
	SUPERINIT

	/* Empty the cache in case other test classes don't do it in -releaseForTest.
	   If the cache doesn't get emptied, cached objects may point to invalid 
	   contexts each time a context is released. COObject->_objectContext is a 
	   weak refence.
	   TODO: Implement a cleanup strategy for contexts that got released. */
	[COObjectServer makeNewDefaultServer];
	/* SubObject persistency is turned on in -[SubObject init] */
	[COGroup setAutomaticallyMakeNewInstancesPersistent: YES];
	[COObjectContext setCurrentContext: NEW(COObjectContext)];

	[self setUpTestGraph];

	return self;
}

/* Object version tuples:
   - { 0, 0, 0, 2, 4, 0 } at v12
   - { 2, 0, 0, 4, 5, 0 } at v17 */
- (void) setUpTestGraph
{
	// context v0
	object = [[SubObject alloc] init]; // context v1
	object2 = [[SubObject alloc] init];
	object3 = [[SubObject alloc] init];
	group = [[COGroup alloc] init];
	group2 = [[COGroup alloc] init];
	group3 = [[COGroup alloc] init];

	UKObjectsEqual([COObjectContext currentContext], [object objectContext]);
	UKObjectsEqual([COObjectContext currentContext], [group objectContext]);

	[group2 setValue: @"blizzard" forProperty: kCOGroupNameProperty];
	[group2 setValue: @"cloud" forProperty: kCOGroupNameProperty];
	[group2 addMember: object2]; 
	[group2 setValue: @"tulip" forProperty: kCOGroupNameProperty];
	[group addMember: object];
	[group addGroup: group2];  // context v12
	[group addGroup: group3]; 
	[group removeGroup: group2]; 
	[group2 addMember: object3];

	[object setValue: @"me" forProperty: @"whoami"]; 
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"]; // context v17
}

- (void) releaseForTest
{
	[COObjectServer makeNewDefaultServer];
	[COGroup setAutomaticallyMakeNewInstancesPersistent: NO];
	[COObjectContext setCurrentContext: NEW(COObjectContext)];
	
	DESTROY(object);
	DESTROY(object2);
	DESTROY(object3);
	DESTROY(group);
	DESTROY(group2);
	DESTROY(group3);
	
	[super release];
}

- (id) currentInstance: (id)anObject
{
	return [[CTXT objectServer] cachedObjectForUUID: [anObject UUID]];
}

- (void) memorizeCurrentInstanceVersions
{
	memorizedVersions[0] = [[self currentInstance: object] objectVersion];
	memorizedVersions[1] = [[self currentInstance: object2] objectVersion];
	memorizedVersions[2] = [[self currentInstance: object3] objectVersion];
	memorizedVersions[3] = [[self currentInstance: group] objectVersion];
	memorizedVersions[4] = [[self currentInstance: group2] objectVersion];
	memorizedVersions[5] = [[self currentInstance: group3] objectVersion];
}

- (void) checkRestoredObjectsAtVersion4: (int *)increments
{
	// NOTE: If REAL_RESTORE_POINT_TRAVERSAL isn't defined in 
	// COObjectContext(GraphRollback), the next four tests can fail if you 
	// restore from a version for which these objects are loaded, see the 
	// comment for the aforementioned macro explains why...
	UKNil([self currentInstance: group2]);
	UKNil([self currentInstance: group3]);
	UKIntsEqual(4, [[CTXT registeredObjects] count]);
	UKIntsEqual(4, [[[CTXT objectServer] cachedObjects] count]);

	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject = [self currentInstance: object];

	UKTrue([newObject isTemporalInstance: object]);
	UKIntsEqual(memorizedVersions[0] + increments[0], [newObject objectVersion]);
	UKStringsEqual(@"Nobody", [newObject valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject valueForProperty: @"otherObjects"]);

	id newGroup = [self currentInstance: group];

	UKIntsEqual(memorizedVersions[3] + increments[3], [newGroup objectVersion]);
	UKNil([newGroup valueForProperty: kCOGroupNameProperty]);
	UKTrue([[newGroup valueForProperty: kCOGroupChildrenProperty] isEmpty]);
	UKTrue([[newGroup valueForProperty: kCOGroupSubgroupsProperty] isEmpty]);
}

- (void) checkRolledbackObjectsAtVersion12
{
	UKIntsEqual(6, [[CTXT registeredObjects] count]);
	UKIntsEqual(6, [[[CTXT objectServer] cachedObjects] count]);
	
	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject = [self currentInstance: object];

	UKTrue([newObject isTemporalInstance: object]);
	UKIntsEqual([object objectVersion] + 1, [newObject objectVersion]);
	UKStringsEqual(@"Nobody", [newObject valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject valueForProperty: @"otherObjects"]);

	id newGroup = [self currentInstance: group];
	id newGroup2 = [self currentInstance: group2];

	UKIntsEqual([group objectVersion] + 1, [newGroup objectVersion]);
	UKNil([newGroup valueForProperty: kCOGroupNameProperty]);
	UKObjectsEqual(A(newObject), [newGroup valueForProperty: kCOGroupChildrenProperty]);
	UKObjectsEqual(A(newGroup2), [newGroup valueForProperty: kCOGroupSubgroupsProperty]);

	UKIntsEqual([group2 objectVersion] + 1, [newGroup2 objectVersion]);
	UKStringsEqual(@"tulip", [newGroup2 valueForProperty: kCOGroupNameProperty]);
	/* object2 version doesn't change in CREATE_OBJECT_GRAPH, hence the initial instance is still valid */
	UKObjectsEqual(A(object2), [newGroup2 valueForProperty: kCOGroupChildrenProperty]);
	UKTrue([[newGroup2 valueForProperty: kCOGroupSubgroupsProperty] isEmpty]);	
}

/* object2, object3 and group3 are not altered once created, thereby their 
   instances remain valid even if the context is rolled backward or forward. 
   However if the context is destroyed and recreated, new instances are 
   created and those initial instances become invalid.
   Their object version also remain equal to 0 in all cases.  */
- (void) checkRolledbackObjectsAtVersion16: (int *)increments
                        invalidatedObjects: (NSArray *)invalidObjects
{
	UKIntsEqual(6, [[CTXT registeredObjects] count]);
	UKIntsEqual(6, [[[CTXT objectServer] cachedObjects] count]);

	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject = [self currentInstance: object];
	id newObject2 = [self currentInstance: object2];
	id newObject3 = [self currentInstance: object3];

	if ([invalidObjects containsObject: object])
		UKTrue([newObject isTemporalInstance: object]);
	UKIntsEqual([object objectVersion] + increments[0], [newObject objectVersion]);
	UKStringsEqual(@"me", [newObject valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject valueForProperty: @"otherObjects"]);

	UKIntsEqual(0, [newObject2 objectVersion]);
	UKStringsEqual(@"Nobody", [newObject2 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject2 valueForProperty: @"otherObjects"]);

	UKIntsEqual(0, [newObject3 objectVersion]);
	UKStringsEqual(@"Nobody", [newObject3 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject3 valueForProperty: @"otherObjects"]);

	id newGroup = [self currentInstance: group];
	id newGroup2 = [self currentInstance: group2];
	id newGroup3 = [self currentInstance: group3];

	if ([invalidObjects containsObject: group])
		UKTrue([newGroup isTemporalInstance: group]);
	UKIntsEqual([group objectVersion] + increments[3], [newGroup objectVersion]);
	UKNil([newGroup valueForProperty: kCOGroupNameProperty]);
	UKObjectsEqual(A(newObject), [newGroup valueForProperty: kCOGroupChildrenProperty]);
	UKObjectsEqual(A(newGroup3), [newGroup valueForProperty: kCOGroupSubgroupsProperty]);

	if ([invalidObjects containsObject: group2])
		UKTrue([newGroup2 isTemporalInstance: group2]);
	UKIntsEqual([group2 objectVersion] + increments[4], [newGroup2 objectVersion]);
	UKStringsEqual(@"tulip", [newGroup2 valueForProperty: kCOGroupNameProperty]);
	UKObjectsEqual(A(newObject2, newObject3), [newGroup2 valueForProperty: kCOGroupChildrenProperty]);
	UKTrue([[newGroup2 valueForProperty: kCOGroupSubgroupsProperty] isEmpty]);	

	UKIntsEqual(0, [newGroup3 objectVersion]);
	UKTrue([[newGroup3 valueForProperty: kCOGroupChildrenProperty] isEmpty]);
	UKTrue([[newGroup3 valueForProperty: kCOGroupSubgroupsProperty] isEmpty]);
}

- (void) checkRolledbackObjectsForRedo
{
	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject2 = [self currentInstance: object];

	UKTrue([newObject2 isTemporalInstance: object]);
	UKIntsEqual([object objectVersion] + 2, [newObject2 objectVersion]);
	UKStringsEqual(@"me", [newObject2 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [newObject2 valueForProperty: @"otherObjects"]);
}

- (void) checkRestoredObjectsForAlter: (int *)increments
{
	UKIntsEqual(6, [[CTXT registeredObjects] count]);
	UKIntsEqual(6, [[[CTXT objectServer] cachedObjects] count]);

	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject = [self currentInstance: object];
	id newObject2 = [self currentInstance: object2];
	id newObject3 = [self currentInstance: object3];

	UKIntsEqual(memorizedVersions[0] + increments[0], [newObject objectVersion]);
	UKStringsEqual(@"Nobody", [newObject valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject valueForProperty: @"otherObjects"]);

	UKIntsEqual(memorizedVersions[1] + increments[1], [newObject2 objectVersion]);
	UKStringsEqual(@"anyone", [newObject2 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject2 valueForProperty: @"otherObjects"]);

	UKIntsEqual(memorizedVersions[2] + increments[2], [newObject3 objectVersion]);
	UKStringsEqual(@"Nobody", [newObject3 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject3 valueForProperty: @"otherObjects"]);

	id newGroup = [self currentInstance: group];
	id newGroup2 = [self currentInstance: group2];
	id newGroup3 = [self currentInstance: group3];

	UKIntsEqual(memorizedVersions[3] + increments[3], [newGroup objectVersion]);
	UKNil([newGroup valueForProperty: kCOGroupNameProperty]);
	UKTrue([[newGroup valueForProperty: kCOGroupChildrenProperty] isEmpty]);
	UKObjectsEqual(A(newGroup2, newGroup3), [newGroup valueForProperty: kCOGroupSubgroupsProperty]);

	UKIntsEqual(memorizedVersions[4] + increments[4], [newGroup2 objectVersion]);
	UKStringsEqual(@"tulip", [newGroup2 valueForProperty: kCOGroupNameProperty]);
	UKObjectsEqual(A(newObject2), [newGroup2 valueForProperty: kCOGroupChildrenProperty]);
	UKTrue([[newGroup2 valueForProperty: kCOGroupSubgroupsProperty] isEmpty]);	

	UKIntsEqual(memorizedVersions[5] + increments[5], [newGroup3 objectVersion]);
	UKStringsEqual(@"zzz", [newGroup3 valueForProperty: kCOGroupNameProperty]);
	UKObjectsEqual(A(newObject3), [newGroup3 valueForProperty: kCOGroupChildrenProperty]);
	UKTrue([[newGroup3 valueForProperty: kCOGroupSubgroupsProperty] isEmpty]);
}

- (void) testContextRollbackTo17
{
	int lastVersion = 17;

	UKIntsEqual(lastVersion, [CTXT version]);

	/* Move back to the previous version (undo) */

	[CTXT restoreToVersion: lastVersion - 1];
	UKIntsEqual((lastVersion + 1), [CTXT version]);

	int objectVersionIncrements[] = { 1, 0, 0, 0, 0, 0 };
	[self checkRolledbackObjectsAtVersion16: objectVersionIncrements
	                     invalidatedObjects: A(object)];

	/* Move back to the initial version (redo) */
	[CTXT restoreToVersion: lastVersion];
	UKIntsEqual((lastVersion + 2), [CTXT version]);

	[self checkRolledbackObjectsForRedo];
}

- (void) recreateObjectGraph
{
	/* Resolving faults on the root group or even all groups isn't enough to 
	   ensure every objects are loaded, because for some context versions 
	   objects might still be part of the context but not belonging to any 
	   groups and thereby disconnected from the graph.
	   For example, at context v16, group2 and object2 are disconnected.
	   At context v12, object3 is disconnected. */
	[CTXT loadAllObjects];
	
	/* -resolvePendingFaultsWithinCachedGraph: would be equivalent, but adds 
	   yet another layer for testing purpose, so we simply call -resolveFaults 
	   on each group. If debugging is necessary, it helps a bit. */
	[[self currentInstance: group] resolveFaults];
	[[self currentInstance: group2] resolveFaults];
	[[self currentInstance: group3] resolveFaults];
}

- (void) testRecreateContextAfterRollback
{
	int lastVersion = 17;

	[CTXT restoreToVersion: 12];

	/* Destroy the context and the object server and recreate them */
	ETUUID *contextUUID = RETAIN([CTXT UUID]);
	[COObjectContext setCurrentContext: nil];
	[COObjectServer makeNewDefaultServer];
	[COObjectContext setCurrentContext: AUTORELEASE([(COObjectContext *)[COObjectContext alloc] initWithUUID: contextUUID])];

	/* All objects are faults, thereby we must load them */
	[self recreateObjectGraph];

	UKIntsEqual(lastVersion + 1, [CTXT version]);
	[self checkRolledbackObjectsAtVersion12];

	/* More rollbacks */

	[self memorizeCurrentInstanceVersions];
	[CTXT restoreToVersion: 4];
	UKIntsEqual(lastVersion + 2, [CTXT version]);
	int objectVersionIncrements[] = { 1, 0, 0, 1, 0, 0 };
	[self checkRestoredObjectsAtVersion4: objectVersionIncrements];

	[CTXT restoreToVersion: 16];
	/* We move forward in time, every objects created after v4 must be loaded 
	   explicitly to work around the lazy loading (aka faulting). */
	[self recreateObjectGraph];
	UKIntsEqual(lastVersion + 3, [CTXT version]);
	/* See -checkRolledbackObjectsAtVersion16:invalidatedObjects: for 
	   explanations about invalidated objects */
	int objectVersionIncrements2[] = { 3, 0, 0, 3, 2, 0 };
	[self checkRolledbackObjectsAtVersion16: objectVersionIncrements2
	                     invalidatedObjects: A(object, group, group2)];

	[self memorizeCurrentInstanceVersions];
	[CTXT restoreToVersion: 19];
	UKIntsEqual(lastVersion + 4, [CTXT version]);
	int objectVersionIncrements3[] = { 1, 0, 0, 1, 0, 0 };
	/* Will fail if REAL_RESTORE_POINT_TRAVERSAL isn't defined, see 
	   -checkRestoredObjectsAtVersion4: */
	[self checkRestoredObjectsAtVersion4: objectVersionIncrements3];

	DESTROY(contextUUID);
}

/* Changes to be applied after restoring the context to version 12.
   Returns the number of changes (the context version increment).
   Object version increments: { 0, 1, 0, 2, 0, 2 } */
- (int) alterCurrentObjectGraph
{
	[[self currentInstance: object2] setValue: @"anyone" forProperty: @"whoami"];
	[[self currentInstance: group3] setValue: @"zzz" forProperty: kCOGroupNameProperty];
	[[self currentInstance: group] removeMember: [self currentInstance: object]];
	[[self currentInstance: group3] addMember: [self currentInstance: object3]];
	[[self currentInstance: group] addGroup: [self currentInstance: group3]];

	return 5;
}

/* Not yet used */
- (void) alterCurrentObjectGraphMore
{
	[object setValue: A([NSNumber numberWithInt: 5]) forProperty: @"otherObjects"];
	[group3 addGroup: group]; // cyclic structure	
}

- (void) testRestoreFollowingRestoreAndChanges
{
	int lastVersion = 17;

	[CTXT restoreToVersion: 12];
	UKIntsEqual(lastVersion + 1, [CTXT version]);
	[self checkRolledbackObjectsAtVersion12];

	[self memorizeCurrentInstanceVersions];
	int nbOfChanges = [self alterCurrentObjectGraph];
	int alterVersion = lastVersion + 1 + nbOfChanges;
	UKIntsEqual(alterVersion, [CTXT version]);

	/* Object version tuple right after restore to v12:
	       -setUpTestGraph at v17  { 2, 0, 0, 4, 5, 0 }
	       -setUpTestGraph at v12  { 0, 0, 0, 2, 4, 0 }
	    -> -restoreToVersion: 12   { 3, 0, 0, 5, 6, 0 }

	    The -> operator means increments each version listed on the first line 
	    if the corresponding version on the second line is different.

        Object version tuple at this point:
	     -restoreToVersion: 12     { 3, 0, 0, 5, 6, 0 }
	   + -alterCurrentObjectGraph  { 0, 1, 0, 2, 0, 2 } (delta)
	                               { 3, 1, 0, 7, 6, 2 }

	   Increment tuple at this point as a delta against v17:
	     -restoreToVersion: 12     { 1, 0, 0, 1, 1, 0 } (delta)
	   + -alterCurrentObjectGraph  { 0, 1, 0, 2, 0, 2 } (delta)
	                               { 1, 1, 0, 3, 1, 2 } (delta)
	
	   Presently we only need the increment tuple against v18 (restored v12) 
	   which is simply -alterCurrentObjectGraph  { 0, 1, 0, 2, 0, 2 } (delta) */
	int objectVersionIncrements[] = { 0, 1, 0, 2, 0, 2 };
	[self checkRestoredObjectsForAlter: objectVersionIncrements];

	[self memorizeCurrentInstanceVersions];
	[CTXT restoreToVersion: 4];

	/* Object version tuple right after this restore to v4:
	         -alterCurrentObjectGraph  { 3, 1, 0, 7, 6, 2 }
	       + -restoreToVersion: 4      { 1, 1, 0, 1, 0, 0 } (delta)
	                                   { 4, 2, 0, 8, 6, 2 } */
	int objectVersionIncrements2[] = { 1, 1, 0, 1, 0, 0 };
	[self checkRestoredObjectsAtVersion4: objectVersionIncrements2];

	[self memorizeCurrentInstanceVersions];
	[CTXT restoreToVersion: alterVersion];
	/* Object version tuple right after this restore to 'alter' version state:
	         -restoreToVersion: 4        { 4, 2, 0, 8, 6, 2 } 
	       + -restoreToVersion: 'alter'  { 1, 1, 0, 1, 0, 0 } (delta)
	                                     { 5, 3, 0, 9, 6, 2 }
	
	   At v4, group3 is missing in the cache so memorizedVersions[5] is zero, 
	   that's why we pass its latest version 2. Moreover it is not changed from 
	   v4 to 'alter' version so it won't restored. Same for group2, but in this 
	   case:

	   context              group2 
	   v17                 -> v5
	   v24 (restore 12)    -> v6
	   v18..23             -> nothing (no modifications)
	   v25 (restore 4)     -> nothing (not yet created, hence disconnected) 
	   v26 (restore alter) -> nothing ('alter' implies no modifications) 
	
	   Alternatively we could do [CTXT loadAllObjects]. */
	int objectVersionIncrements3[] = { 1, 1, 0, 1, 6, 2 };
	[self recreateObjectGraph];
	[self checkRestoredObjectsForAlter: objectVersionIncrements3];
}

@end

@implementation SubObject

+ (void) initialize
{
	[super initialize];

	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt: kCOStringProperty],
            @"whoami",
        [NSNumber numberWithInt: kCOArrayProperty],
            @"otherObjects",
        nil];
    [self addPropertiesAndTypes: pt];
	[self setAutomaticallyMakeNewInstancesPersistent: YES];

    DESTROY(pt);
}

- (id) init
{
	SUPERINIT

	[self setValue: @"Nobody"
	      forProperty: @"whoami"];
	[self setValue: [NSMutableArray arrayWithObject: @"New York"]
	      forProperty: @"otherObjects"];
	[self tryStartPersistencyIfInstanceOfClass: [SubObject class]];

	return self;
}

@end
