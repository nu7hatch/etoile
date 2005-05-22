#include <LuceneKit/Util/NSData+Additions.h>
#include <LuceneKit/GNUstep/GNUstep.h>
#include <zlib.h>

@implementation NSData (LuceneKit_Util)
- (NSData *) compressedData
{
	NSData *result = nil;
	unsigned int srcLength = [self length];
	if (srcLength > 0)
	{
		uLong buffLength = srcLength * 1.001 + 12;
		NSMutableData *compData = [[NSMutableData alloc] initWithCapacity:buffLength];
		[compData increaseLengthBy:buffLength];
		int error = compress( [compData mutableBytes], &buffLength,
							  [self bytes], srcLength );
		switch( error ) {
			case Z_OK:
				[compData setLength: buffLength];
				ASSIGNCOPY(result, compData);
				break;
			default:
				NSAssert( YES, @"Error compressing: Memory Error!" );
				break;
		}
		RELEASE(compData);
    }
    return AUTORELEASE(result);
}

- (NSData *) decompressedData
{
	if ([self length] == 0) return self;
	
	unsigned full_length = [self length];
	unsigned half_length = [self length] / 2;
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = [self length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit (&strm) != Z_OK) return nil;
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = [decompressed mutableBytes] + strm.total_out;
		strm.avail_out = [decompressed length] - strm.total_out;
		
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
	
	// Set real length.
	if (done)
	{
		[decompressed setLength: strm.total_out];
		return [NSData dataWithData: decompressed];
	}
	else 
		return nil;

}
@end

#ifdef HAVE_NEW_UKTEST

#include <UnitKit/UnitKit.h>
@interface TestCompressData: NSObject <UKTest>
@end

@implementation TestCompressData
- (void) testCompresion
{
	NSString *s = @"GNUstep is a free, object-oriented, cross-platform development environment that strives for simplicity and elegance. GNUstep is based on and completely compatible with the OpenStep specification developed by NeXT (now Apple Computer Inc.) as well as implementing many extensions including Mac OS X/Cocoa.";
	NSData *orig = [s dataUsingEncoding: NSUTF8StringEncoding];
	NSLog(@"Original size %d", [orig length]);
	NSData *compressed = [orig compressedData];
	NSLog(@"Compressed size %d", [compressed length]);
	NSData *decompressed = [compressed decompressedData];
	NSLog(@"Decompressed size %d", [decompressed length]);
	UKIntsEqual([orig length], [decompressed length]);
	NSString *d = [[NSString alloc] initWithData: decompressed encoding: NSUTF8StringEncoding];
	UKIntsEqual([s length], [d length]);
	UKStringsEqual(s, d);
}
@end

#endif