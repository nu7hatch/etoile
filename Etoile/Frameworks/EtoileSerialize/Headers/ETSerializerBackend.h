/**
 * <author name="David Chisnall"></author>
 */
#import <Foundation/Foundation.h>
#import <EtoileSerialize/ETUtility.h>

@protocol ETSerialObjectStore;

/**
 * The ETSerializerBackend protocol is a formal protocol defining the interface
 * for serializer backends.  The backend is responsible for storing the data
 * passed to it representing instance variables of objects in a way that can be
 * read by a corresponding deserializer backend.
 *
 * For each serializer backend class, a mirror class that implements 
 * ETDeserializerBackend protocol has to be implemented.
 */
@protocol ETSerializerBackend <NSObject>
//Setup
/**
 * Create a new instance of the back end writing to the specified store.
 */
+ (id) serializerBackendWithStore:(id<ETSerialObjectStore>)aStore;
/**
 * <init /> 
 * Initialise a new instance with the specified store.
 *
 * Raises an NSInvalidArgumentException if the store is not valid e.g. nil.
 */
- (id) initWithStore:(id<ETSerialObjectStore>)aStore;
/**
 * Returns the deserializer backend class which is the mirror of this
 * serializer backend.
 */
+ (Class) deserializerBackendClass;
/**
 * Returns a deserializer backend instance initialised with the same data
 * source (URL or data) as this serializer backend.
 */
- (id) deserializerBackend;
/**
 * Perform any initialisation required on the new version.
 */
- (void) startVersion:(int)aVersion;
/**
 * Ensures data has been written.
 */
- (void) flush;
//Objects
/**
 * Store the class version to be associated with the next set of instance
 * variables.
 */
- (void) setClassVersion:(int)aVersion;
/**
 * Begin a new object of the specified class.  All subsequent messages until
 * the corresponding -endObject message should be treated as belonging to this
 * object.
 *
 * Note that unlike structures and arrays, objects will not be nested.
 */
- (void) beginObjectWithID:(CORef)aReference withName:(char*)aName withClass:(Class)aClass;
/**
 * Sent when an object has been completely serialized.
 */
- (void) endObject;
/**
 * Store a reference to an Objective-C object in the named instance variable.
 * This is equivalent to an id, but is not guaranteed to correspond to an
 * actual memory address either before or after serialization.
 */
- (void) storeObjectReference:(CORef)aReference withName:(char*)aName;
/**
 * Increment the reference count for the object with the specified reference.
 */
- (void) incrementReferenceCountForObject:(CORef)anObjectID;
//Nested types
/**
 * Begin storing a structure.  Subsequent messages will correspond to fields in
 * this structure until a corresponding -endStruct message is received.
 *
 * The aStructName stores the name of the structure type.  This is
 * used by the deserializer to identify a custom structure deserializer to use.
 */
- (void) beginStruct:(char*)aStructName withName:(char*)aName;
/**
 * Mark the end of a structure.
 */
- (void) endStruct;
/**
 * Begin an array of the specified length.
 */
- (void) beginArrayNamed:(char*)aName withLength:(unsigned int)aLength;
/**
 * Mark the end of an array.
 */
- (void) endArray;
//Intrinsics
/**
 * Store the value aChar for the instance variable aName.
 */
- (void) storeChar:(char)aChar withName:(char*)aName;
/**
 * Store the value aChar for the instance variable aName.
 */
- (void) storeUnsignedChar:(unsigned char)aChar withName:(char*)aName;
/**
 * Store the value aShort for the instance variable aName.
 */
- (void) storeShort:(short)aShort withName:(char*)aName;
/**
 * Store the value aShort for the instance variable aName.
 */
- (void) storeUnsignedShort:(unsigned short)aShort withName:(char*)aName;
/**
 * Store the value aInt for the instance variable aName.
 */
- (void) storeInt:(int)aInt withName:(char*)aName;
/**
 * Store the value aInt for the instance variable aName.
 */
- (void) storeUnsignedInt:(unsigned int)aInt withName:(char*)aName;
/**
 * Store the value aLong for the instance variable aName.
 */
- (void) storeLong:(long)aLong withName:(char*)aName;
/**
 * Store the value aLong for the instance variable aName.
 */
- (void) storeUnsignedLong:(unsigned long)aLong withName:(char*)aName;
/**
 * Store the value aLongLong for the instance variable aName.
 */
- (void) storeLongLong:(long long)aLongLong withName:(char*)aName;
/**
 * Store the value aLongLong for the instance variable aName.
 */
- (void) storeUnsignedLongLong:(unsigned long long)aLongLong withName:(char*)aName;
/**
 * Store the value aFloat for the instance variable aName.
 */
- (void) storeFloat:(float)aFloat withName:(char*)aName;
/**
 * Store the value aDouble for the instance variable aName.
 */
- (void) storeDouble:(double)aDouble withName:(char*)aName;
/**
 * Store the value aClass for the instance variable aName.
 */
- (void) storeClass:(Class)aClass withName:(char*)aName;
/**
 * Store the value aChar for the instance variable aName.
 */
- (void) storeSelector:(SEL)aSelector withName:(char*)aName;
/**
 * Store the value aCString for the instance variable
 * aName.  The backend should ensure it copies the string, rather
 * than simply retaining a reference to it.
 */
- (void) storeCString:(const char*)aCString withName:(char*)aName;
/**
 * Store the value aBlob for the instance variable aName.
 * The data should be copied by the backend.
 */
- (void) storeData:(void*)aBlob ofSize:(size_t)aSize withName:(char*)aName;
/**
 * Stores an UUID reference for the instance variable aName. 
 */
- (void) storeUUID:(unsigned char *)aUUID withName:(char *)aName;
@end

