#import "ETDeserialiser.h"

inline static void * addressForIVarName(id anObject, char * aName, int hint)
{
	//Find a real iVar
	struct objc_ivar_list* ivarlist = anObject->class_pointer->ivars;
	if(ivarlist != NULL) 
	{
		for(int i=0 ; i<ivarlist->ivar_count ; i++)
		{
			char * name = (char*)ivarlist->ivar_list[i].ivar_name;
			if(strcmp(aName, name) == 0)
			{
				return ((char*)anObject + (ivarlist->ivar_list[i].ivar_offset));
			}
		}
	}
	return NULL;
}

@protocol _COAwareObject
- (void) finishedDeserialising;
@end

#define SET_REF(ref, obj) NSMapInsert(loadedObjects, (void*)ref, (void*) obj)
#define GET_OBJ(ref) (id)NSMapGet(loadedObjects, (void*)ref)
//TODO: Add bounds checking to this and some overflow capability
//for stupidly nested objects.
#define STATE states[stackTop]
#define PUSH_STATE(offset, stateType) ++stackTop;STATE.startOffset = offset; STATE.type = stateType; STATE.index = loadedIVar; loadedIVar = 0;// NSLog(@"Pushing state '%c'", stateType);
#define PUSH_STRUCT(offset) PUSH_STATE(offset, 's')
#define PUSH_ARRAY(offset) PUSH_STATE(offset, 'a')
#define POP() loadedIVar = states[stackTop--].index;

#define OFFSET_OF_IVAR(object, name, hint, type) offsetOfIvar(object, name, hint, sizeof(type), stackTop, &STATE)

inline static void * offsetOfIvar(id anObject, char * aName, int hint, int size, int stackTop, ETDeserialiserState * state)
{
	if(stackTop == 0)
	{
		return addressForIVarName(anObject, aName, hint);
	}
	else
	{
		//NSLog(@"Inside nested type looking for %s.", aName);
		switch(state->type)
		{
			case 'a':
				{
					return state->startOffset + size * hint;
				}
			case 's':
				{
					//TODO: Make this alignment-aware
					void * offset = state->startOffset;
					state->startOffset += size;
					while((int)state->startOffset % __alignof__(int) != 0)
					{
						state->startOffset++;
					}
					return offset;
				}
			default:
				{
					NSLog(@"Invalid state '%c'!  No skill!", state->type);\
				}
		}
		return NULL;
	}
}

@implementation ETDeserialiser
- (id) init
{
	if(nil == (self = [super init]))
	{
		return nil;
	}
	const NSMapTableKeyCallBacks keycallbacks = {NULL, NULL, NULL, NULL, NULL, NSNotAnIntMapKey};
	const NSMapTableValueCallBacks valuecallbacks = {NULL, NULL, NULL};
	//TODO: After we've got some real profiling data, 
	//change 100 to a more sensible value
	loadedObjects = NSCreateMapTable(keycallbacks, valuecallbacks, 100);
	objectPointers = NSCreateMapTable(keycallbacks, valuecallbacks, 100);
	loadedObjectList = [[NSMutableArray alloc] init];
	return self;
}
- (void) setBackend:(id<ETDeserialiserBackend>)aBackend
{
	backend = [aBackend retain];
	[backend setDeserialiser:self];
}
+ (ETDeserialiser*) deserialiserWithBackend:(id<ETDeserialiserBackend>)aBackend
{
	ETDeserialiser * deserialiser = [[[ETDeserialiser alloc] init] autorelease];
	[deserialiser setBackend:aBackend];
	return deserialiser;
}
- (void) setClassVersion:(int)aVersion
{
	classVersion = aVersion;
}
- (id) restoreObjectGraph
{
	CORef mainObject = [backend principalObject];
	[backend deserialiseObjectWithID:mainObject];
	//Also restore referenced objects
	NSMapEnumerator enumerator = NSEnumerateMapTable(objectPointers);
	CORef ref;
	id * pointer;
	while(NSNextMapEnumeratorPair(&enumerator, (void*)&pointer, (void*)&ref))
	{
		//NSLog(@"Setting *(id*)0x%x=%d", pointer, ref);
		*pointer = GET_OBJ(ref);
		//If we haven't already loaded this object
		if(*pointer == NULL)
		{
			[backend deserialiseObjectWithID:ref];
			*pointer = GET_OBJ(ref);
		}
		NSMapRemove(objectPointers, pointer);
		//Restart the enumeration
		NSEndMapTableEnumeration(&enumerator);
		enumerator = NSEnumerateMapTable(objectPointers);
	}
	NSEnumerator * finishedEnumerator = [loadedObjectList objectEnumerator];
	id finishedObject;
	while((finishedObject = [finishedEnumerator nextObject]) != nil)
	{
		[finishedObject finishedDeserialising];
	}
	[loadedObjectList removeAllObjects];
	return GET_OBJ(mainObject);
}
//Objects
- (void) beginObjectWithID:(CORef)aReference withClass:(Class)aClass 
{
	loadedIVar = 0;
	//TODO: Decide if this should call init.  Probably not...
	object = [aClass alloc];
	SET_REF(aReference, object);
}
- (void) endObject 
{
	if(class_get_instance_method(object->class_pointer, @selector(finishedDeserialising)))
	{
		[loadedObjectList addObject:object];
	}
}
#define LOAD_INTRINSIC(type, name) \
{\
	if(![object deserialise:aName fromPointer:&aVal version:classVersion])\
	{\
		char * address = OFFSET_OF_IVAR(object, aName, loadedIVar++, type);\
		if(address != NULL)\
		{\
			*(type*)address = aVal;\
		}\
	}\
}
- (void) loadObjectReference:(CORef)aReference withName:(char*)aName
{
	if(![object deserialise:aName fromPointer:&aName version:classVersion])
	{
		if(aReference != 0)
		{
			id aVal = GET_OBJ(aReference);
			if(aVal != nil)
			{
				LOAD_INTRINSIC(id, aName);
			}
			else
			{
				void * pointer = OFFSET_OF_IVAR(object, aName, loadedIVar++, id);
				NSMapInsert(objectPointers, pointer, (void*)aReference);
			}
		}
		else
		{
			char * address = OFFSET_OF_IVAR(object, aName, loadedIVar++, id);
			if(address != NULL)
			{
				*(id*)address = nil;
			}
		}
	}
}
- (void) setReferenceCountForObject:(CORef)anObjectID to:(int)aRefCount 
{
	id obj = GET_OBJ(anObjectID);
	while(aRefCount-- > 1)
	{
		RETAIN(obj);
	}
}
//Nested types
- (void) beginStructNamed:(char*)aName 
{
	//TODO: Change this 10 to something correct
	char * address = OFFSET_OF_IVAR(object, aName, loadedIVar++, 10);
	//NSLog(@"Struct address = 0x%x", address);
	if(address != NULL)
	{
		PUSH_STRUCT(address);
	}
}
- (void) endStruct 
{
	POP();
}
- (void) beginArrayNamed:(char*)aName withLength:(unsigned int)aLength
{
	char * address = OFFSET_OF_IVAR(object, aName, loadedIVar++, aLength);

	if(address != NULL)
	{
		PUSH_ARRAY(address);
	}
}
- (void) endArray 
{
	POP();
}
//Intrinsics
#define LOAD_METHOD(name, type) - (void) load ## name:(type)aVal withName:(char*)aName LOAD_INTRINSIC(type, name)
LOAD_METHOD(Char, char)
LOAD_METHOD(UnsignedChar, unsigned char)
LOAD_METHOD(Short, short)
LOAD_METHOD(UnsignedShort, unsigned short)
LOAD_METHOD(Int, int)
LOAD_METHOD(UnsignedInt, unsigned int)
LOAD_METHOD(Long, long)
LOAD_METHOD(UnsignedLong, unsigned long)
LOAD_METHOD(LongLong, long long)
LOAD_METHOD(UnsignedLongLong, unsigned long long)
LOAD_METHOD(Float, float)
LOAD_METHOD(Double, double)
LOAD_METHOD(Class, Class)
LOAD_METHOD(Selector, SEL)
- (void) loadCString:(char*)aCString withName:(char*)aName
{
	if(![object deserialise:aName fromPointer:aCString version:classVersion])
	{
		char * address = OFFSET_OF_IVAR(object, aName, loadedIVar++, sizeof(char*));
		if(address != NULL)
		{
			*(char**)address = strdup(aCString);
		}
	}
}
- (void) loadData:(void*)aBlob ofSize:(size_t)aSize withName:(char*)aName 
{
	if(![object deserialise:aName fromPointer:aBlob version:classVersion])
	{
		char * address = OFFSET_OF_IVAR(object, aName, loadedIVar++, aSize);
		if(address != NULL)
		{
			memcpy(address, aBlob, aSize);
		}
	}
}

- (void) dealloc
{
	NSFreeMapTable(loadedObjects);
	[backend release];
	[loadedObjectList release];
	[super dealloc];
}
@end
