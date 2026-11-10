#pragma once

#include <stddef.h>
#include <stdint.h>

typedef unsigned short UniChar;
typedef unsigned char UInt8;
typedef long CFIndex;
typedef unsigned long CFStringEncoding;
typedef struct { CFIndex location, length; } CFRange;
static inline CFRange CFRangeMake(CFIndex location, CFIndex length) {
    return {location, length};
}
typedef const void *CFTypeRef;
typedef const void *CFStringRef;
typedef const void *CFURLRef;
typedef const void *CFMutableDataRef;
typedef const void *CFMutableDictionaryRef;
typedef void *CGContextRef;
typedef void *CGImageRef;
typedef void *CGImageDestinationRef;
typedef struct { double x, y, width, height; } NSRect;
typedef signed char BOOL;
static const void *const kCFAllocatorDefault = nullptr;
static const void *const kUTTypeTIFF = nullptr;
static const CFStringEncoding kCFStringEncodingUTF8 = 0x08000100;
static const int kCFURLPOSIXPathStyle = 0, kCFURLHFSPathStyle = 1;
static const unsigned long NSUnicodeStringEncoding = 10;

extern "C" {
CFStringRef CFStringCreateWithBytes(const void *, const UInt8 *, CFIndex, CFStringEncoding, bool);
CFStringRef CFStringCreateWithCharacters(const void *, const UniChar *, CFIndex);
CFIndex CFStringGetLength(CFStringRef);
void CFStringGetCharacters(CFStringRef, CFRange, UniChar *);
CFIndex CFStringGetMaximumSizeForEncoding(CFIndex, CFStringEncoding);
CFIndex CFStringGetBytes(CFStringRef, CFRange, CFStringEncoding, UInt8, bool, UInt8 *, CFIndex, CFIndex *);
void CFRelease(CFTypeRef);
CFURLRef CFURLCreateWithFileSystemPath(const void *, CFStringRef, int, bool);
CFStringRef CFURLCopyFileSystemPath(CFURLRef, int);
CFMutableDataRef CFDataCreateMutable(const void *, CFIndex);
const UInt8 *CFDataGetBytePtr(CFMutableDataRef);
CFIndex CFDataGetLength(CFMutableDataRef);
CFMutableDictionaryRef CFDictionaryCreateMutable(const void *, CFIndex, const void *, const void *);
CGImageDestinationRef CGImageDestinationCreateWithData(CFMutableDataRef, const void *, size_t, const void *);
void CGImageDestinationAddImage(CGImageDestinationRef, CGImageRef, CFMutableDictionaryRef);
bool CGImageDestinationFinalize(CGImageDestinationRef);
void CGContextScaleCTM(CGContextRef, double, double);
void CGContextTranslateCTM(CGContextRef, double, double);
}

#ifdef __OBJC__
#define NSObject OwnershipObject
#define NSString OwnershipString
#define NSMutableString OwnershipMutableString
#define NSURL OwnershipURL
#define NSData OwnershipData
#define NSPICTImageRep OwnershipPICTImageRep
#define NSImage OwnershipImage
__attribute__((objc_root_class))
@interface NSObject
+ (id)alloc;
- (id)init;
- (oneway void)release;
@end
@interface NSString : NSObject
- (id)initWithCharacters:(const UniChar *)characters length:(unsigned long)length;
- (id)initWithString:(NSString *)string;
- (unsigned long)length;
- (BOOL)getCString:(char *)buffer maxLength:(unsigned long)capacity encoding:(unsigned long)encoding;
- (const char *)UTF8String;
@end
@interface NSMutableString : NSString
@end
@interface NSURL : NSObject
- (id)initWithString:(NSString *)string;
- (NSString *)absoluteString;
@end
@interface NSData : NSObject
- (id)initWithBytes:(const void *)bytes length:(unsigned long)length;
@end
@interface NSPICTImageRep : NSObject
- (id)initWithData:(NSData *)data;
- (NSRect)boundingBox;
- (CGImageRef)CGImageForProposedRect:(NSRect *)rect context:(id)context hints:(id)hints;
@end
@interface NSImage : NSObject
- (void)addRepresentation:(NSPICTImageRep *)representation;
@end
#endif
