#ifndef __LUCENE_INDEX_FIELDS_WRITER__
#define __LUCENE_INDEX_FIELDS_WRITER__

#include <Foundation/Foundation.h>
#include "Store/LCDirectory.h"

#define LCFieldsWriter_FIELD_IS_TOKENIZED 0x1
#define LCFieldsWriter_FIELD_IS_BINARY 0x2
#define LCFieldsWriter_FIELD_IS_COMPRESSED 0x4

@class LCFieldInfos;
@class LCIndexOutput;
@class LCDocument;

@interface LCFieldsWriter: NSObject
{
  LCFieldInfos *fieldInfos;
  LCIndexOutput *fieldsStream;
  LCIndexOutput *indexStream;
}

- (id) initWithDirectory: (id <LCDirectory>) d
                  segment: (NSString *) segment
                   fieldInfos: (LCFieldInfos *) fn;
- (void) close;
- (void) addDocument: (LCDocument *) doc;
@end

#endif /* __LUCENE_INDEX_FIELDS_WRITER__ */
