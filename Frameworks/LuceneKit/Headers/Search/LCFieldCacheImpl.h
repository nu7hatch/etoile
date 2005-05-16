#ifndef __LUCENE_SEARCH_FIELD_CACHE_IMPL__
#define __LUCENE_SEARCH_FIELD_CACHE_IMPL__

#include <LuceneKit/Search/LCSortField.h>
#include <LuceneKit/Search/LCFieldCache.h>

@interface LCEntry: NSObject
{
	NSString *field;
	LCSortFieldType type;
	id custom; // which custom comparator
}

- (id) initWithField: (NSString *) field
				type: (LCSortFieldType) type;
- (id) initWithField: (NSString *) field
			  custom: (id) custom;
- (NSString *) field;
- (LCSortFieldType) type;
- (id) custom;
@end

@interface LCFieldCacheImpl: LCFieldCache
{
	/** The internal cache. Maps Entry to array of interpreted term values. **/
	NSMutableDictionary *cache;
}
- (id) lookup: (LCIndexReader *) reader field: (NSString *) field
		 type: (LCSortFieldType) type;
- (id) lookup: (LCIndexReader *) reader field: (NSString *) field
	 comparer: (id) comparer;
- (id) store: (LCIndexReader *) reader field: (NSString *) field
		type: (LCSortFieldType) type custom: (id) value;
- (id) store: (LCIndexReader *) reader field: (NSString *) field
	comparer: (id) comparer custom: (id) value;
@end

#endif /* __LUCENE_SEARCH_FIELD_CACHE_IMPL__ */
