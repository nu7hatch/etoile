#include "LuceneKit/Store/LCFSIndexOutput.h"
#include "GNUstep.h"

@implementation LCFSIndexOutput

- (id) initWithFile: (NSString *) absolutePath
{
  self = [super init];
  ASSIGN(path, absolutePath);

  // Create a file if it is not exist
  BOOL isDir;
  NSFileManager *manager = [NSFileManager defaultManager];
  if (([manager fileExistsAtPath: path isDirectory: &isDir] == NO))
  {
    if ([manager createFileAtPath: path contents: nil attributes: nil] == NO)
    {
      NSLog(@"Cannot create %@", path);
    }
  }
  else
  {
    if (isDir == YES)
    {
      NSLog(@"Error: File exist, but is a directory");
      return nil;
    }
  }

  ASSIGN(handle, [NSFileHandle fileHandleForUpdatingAtPath: path]);
  if (handle == nil) 
  {
	  NSLog(@"File %@ doesn't exist", path);
	  return nil;
  }

  return self;
}

- (void) writeByte: (char) b
{
  NSData *d = [NSData dataWithBytes: &b length: 1];
  [self writeBytes: d length: 1];
}

- (void) writeBytes: (NSData *) b length: (int) len
{
  NSRange r = NSMakeRange(0, len);
  NSData *d = [b subdataWithRange: r];;
  [handle writeData: d];
}

  /** output methods: */
- (void) flush
{
  [handle synchronizeFile];
}

- (void) close
{
  [handle closeFile];
}

- (unsigned long long) filePointer
{
  [handle offsetInFile];
}

  /** Random-access methods */
- (void) seek: (unsigned long long) pos
{
  [handle seekToFileOffset: pos];
}

- (unsigned long long) length
{
  [handle synchronizeFile];
  NSFileManager *manager = [NSFileManager defaultManager];
  NSDictionary *d = [manager fileAttributesAtPath: path 
                                     traverseLink: YES];
  return [[d objectForKey: NSFileSize] unsignedLongLongValue];
}

- (void) dealloc
{
  [handle closeFile];
  RELEASE(handle);
  RELEASE(path);
  [super dealloc];
}

@end
