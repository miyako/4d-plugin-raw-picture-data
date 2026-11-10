#include "platform.h"
#include "4DPlugin-_o_PICTURE.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"
#include "Classes/ARRAY_TEXT.h"
#include "Classes/C_BLOB.h"
#include "Classes/C_LONGINT.h"

#include <cassert>
#include <codecvt>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <locale>
#include <map>
#include <set>
#include <type_traits>

static_assert(!std::is_copy_constructible<C_TEXT>::value &&
              !std::is_copy_assignable<C_TEXT>::value);
static_assert(std::is_copy_constructible<CBytes>::value &&
              std::is_copy_constructible<C_LONGINT>::value);

[[noreturn]] static void denied() {
    std::fputs("DENIED unexpected platform API or engine selector\n", stderr);
    std::abort();
}

// These Objective-C/image/path surfaces compile but must never reach the OS.
@implementation NSObject
+ (id)alloc { denied(); }
- (id)init { denied(); }
- (oneway void)release { denied(); }
@end
@implementation NSString
- (id)initWithCharacters:(const UniChar *)p length:(unsigned long)n { denied(); }
- (id)initWithString:(NSString *)s { denied(); }
- (unsigned long)length { denied(); }
- (BOOL)getCString:(char *)b maxLength:(unsigned long)n encoding:(unsigned long)e { denied(); }
- (const char *)UTF8String { denied(); }
@end
@implementation NSMutableString
@end
@implementation NSURL
- (id)initWithString:(NSString *)s { denied(); }
- (NSString *)absoluteString { denied(); }
@end
@implementation NSData
- (id)initWithBytes:(const void *)p length:(unsigned long)n { denied(); }
@end
@implementation NSPICTImageRep
- (id)initWithData:(NSData *)d { denied(); }
- (NSRect)boundingBox { denied(); }
- (CGImageRef)CGImageForProposedRect:(NSRect *)r context:(id)c hints:(id)h { denied(); }
@end
@implementation NSImage
- (void)addRepresentation:(NSPICTImageRep *)r { denied(); }
@end

static std::set<const void *> cfOwners;
static std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codec;
static const std::u16string &cf(CFStringRef p) {
    assert(cfOwners.count(p));
    return *static_cast<const std::u16string *>(p);
}
static CFStringRef ownCF(const std::u16string &s) {
    auto *p = new std::u16string(s);
    assert(cfOwners.insert(p).second);
    return p;
}
extern "C" {
CFStringRef CFStringCreateWithBytes(const void *, const UInt8 *p, CFIndex n, CFStringEncoding e, bool) {
    assert(e == kCFStringEncodingUTF8 && n >= 0);
    return ownCF(codec.from_bytes(reinterpret_cast<const char *>(p), reinterpret_cast<const char *>(p) + n));
}
CFStringRef CFStringCreateWithCharacters(const void *, const UniChar *p, CFIndex n) {
    assert(n >= 0);
    return ownCF(std::u16string(reinterpret_cast<const char16_t *>(p), n));
}
CFIndex CFStringGetLength(CFStringRef p) { return cf(p).size(); }
void CFStringGetCharacters(CFStringRef p, CFRange r, UniChar *out) {
    assert(r.location >= 0 && r.length >= 0 && r.location + r.length <= static_cast<CFIndex>(cf(p).size()));
    std::memcpy(out, cf(p).data() + r.location, r.length * sizeof(UniChar));
}
CFIndex CFStringGetMaximumSizeForEncoding(CFIndex n, CFStringEncoding e) {
    assert(e == kCFStringEncodingUTF8 && n >= 0);
    return n * 3;
}
CFIndex CFStringGetBytes(CFStringRef p, CFRange r, CFStringEncoding e, UInt8, bool,
                        UInt8 *out, CFIndex capacity, CFIndex *used) {
    assert(e == kCFStringEncodingUTF8);
    auto bytes = codec.to_bytes(cf(p).substr(r.location, r.length));
    assert(capacity >= static_cast<CFIndex>(bytes.size()));
    std::memcpy(out, bytes.data(), bytes.size());
    *used = bytes.size(); // Bytes, excluding a terminator.
    return r.length;
}
void CFRelease(CFTypeRef p) {
    assert(cfOwners.erase(p) == 1);
    delete static_cast<const std::u16string *>(p);
}
CFURLRef CFURLCreateWithFileSystemPath(const void *, CFStringRef, int, bool) { denied(); }
CFStringRef CFURLCopyFileSystemPath(CFURLRef, int) { denied(); }
CFMutableDataRef CFDataCreateMutable(const void *, CFIndex) { denied(); }
const UInt8 *CFDataGetBytePtr(CFMutableDataRef) { denied(); }
CFIndex CFDataGetLength(CFMutableDataRef) { denied(); }
CFMutableDictionaryRef CFDictionaryCreateMutable(const void *, CFIndex, const void *, const void *) { denied(); }
CGImageDestinationRef CGImageDestinationCreateWithData(CFMutableDataRef, const void *, size_t, const void *) { denied(); }
void CGImageDestinationAddImage(CGImageDestinationRef, CGImageRef, CFMutableDictionaryRef) { denied(); }
bool CGImageDestinationFinalize(CGImageDestinationRef) { denied(); }
void CGContextScaleCTM(CGContextRef, double, double) { denied(); }
void CGContextTranslateCTM(CGContextRef, double, double) { denied(); }
}

static std::map<PA_Handle, size_t> handles;
static std::set<PA_Unichar *> strings;
static size_t stringCreates, stringDisposes, handleCreates, handleDisposes;
static bool allocatedEmpty;
static PA_Unistring makeString(const PA_Unichar *p) {
    size_t n = 0;
    if (p) while (p[n]) ++n;
    PA_Unistring s = {};
    s.fLength = n;
    if (n || allocatedEmpty) {
        s.fString = new PA_Unichar[n + 1]();
        if (n) std::memcpy(s.fString, p, n * sizeof(PA_Unichar));
        auto *allocation = s.fString;
        assert(strings.insert(allocation).second);
        ++stringCreates;
    }
    return s;
}
static void disposeString(PA_Unistring &s) {
    auto *allocation = s.fString;
    if (allocation) {
        assert(strings.erase(allocation) == 1);
        delete[] allocation;
        ++stringDisposes;
    }
    s = {};
}
static void disposeHandle(PA_Handle h) {
    assert(handles.erase(h) == 1);
    delete[] *h;
    delete h;
    ++handleDisposes;
}
static void clear(PA_Variable &v) {
    switch (v.fType) {
        case eVK_Unistring: disposeString(v.uValue.fString); break;
        case eVK_Blob:
            if (v.uValue.fBlob.fHandle) disposeHandle(v.uValue.fBlob.fHandle);
            break;
        case eVK_ArrayUnicode: {
            auto *p = reinterpret_cast<PA_Unistring *>(*v.uValue.fArray.fData);
            for (int i = 0; i <= v.uValue.fArray.fNbElements; ++i) disposeString(p[i]);
            disposeHandle(v.uValue.fArray.fData);
            break;
        }
        case eVK_ArrayBlob: {
            auto *p = reinterpret_cast<PA_Blob *>(*v.uValue.fArray.fData);
            for (int i = 0; i <= v.uValue.fArray.fNbElements; ++i)
                if (p[i].fHandle) disposeHandle(p[i].fHandle);
            disposeHandle(v.uValue.fArray.fData);
            break;
        }
        case eVK_Undefined: break;
        default: denied();
    }
    v = {};
    v.fType = eVK_Undefined;
}
static void engine(short selector, EngineBlock *eb) {
    eb->fError = eER_NoErr;
    switch (selector) {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle));
            break;
        case EX_DISPOSE_UNISTRING: disposeString(eb->fUniString1); break;
        case EX_SET_UNISTRING: {
            auto s = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle));
            disposeString(eb->fUniString1);
            eb->fUniString1 = s;
            break;
        }
        case EX_CLEAR_VARIABLE: clear(*static_cast<PA_Variable *>(eb->fPtr1)); break;
        case EX_GET_PICTURE_DATA:
            // Metadata ownership is unspecified. Only failure is modeled; poison
            // must not be inspected, adopted, or disposed by either dispatcher.
            eb->fError = eER_IncompatibleTypes;
            std::memset(&eb->fUniString1, 0xA5, sizeof eb->fUniString1);
            break;
        case EX_HANDLE_MANAGER: {
            auto h = eb->fParam1 == 1 ? nullptr : eb->fHandle;
            switch (eb->fParam1) {
                case 1:
                    assert(eb->fParam2 >= 0);
                    h = new char *;
                    *h = new char[eb->fParam2]();
                    handles[h] = eb->fParam2;
                    ++handleCreates;
                    eb->fHandle = h;
                    break;
                case 2: disposeHandle(h); break;
                case 3: {
                    assert(handles.count(h) && eb->fParam2 >= 0);
                    auto *p = new char[eb->fParam2]();
                    std::memcpy(p, *h, std::min(handles.at(h), static_cast<size_t>(eb->fParam2)));
                    delete[] *h;
                    *h = p;
                    handles[h] = eb->fParam2;
                    break;
                }
                case 4: eb->fParam2 = handles.at(h); break;
                case 5: assert(handles.count(h)); eb->fParam3 = reinterpret_cast<sLONG_PTR>(*h); break;
                case 6: assert(handles.count(h)); break;
                default: denied();
            }
            break;
        }
        default: denied();
    }
}

template<class T> static void copyProbe(bool assignment) {
    if constexpr (std::is_copy_constructible<T>::value && std::is_copy_assignable<T>::value) {
        T first;
        if (assignment) {
            T second;
            second = first;
        } else {
            T second(first);
        }
    } else {
        static_assert(!std::is_copy_constructible<T>::value && !std::is_copy_assignable<T>::value);
        std::puts("PASS prohibited shallow copy");
    }
}

static void exact(const CUTF16String &s, const std::u16string &expected) {
    assert(s.size() == expected.size());
    assert(std::memcmp(s.data(), expected.data(), expected.size() * sizeof(PA_Unichar)) == 0);
    assert(s.c_str()[s.size()] == 0);
}
static void controls() {
    const std::u16string fixtures[] = {u"", u"ASCII", u"\u65e5\u672c", u"x\U0001f600y"};
    for (bool empty : {false, true}) {
        allocatedEmpty = empty;
        for (const auto &fixture : fixtures) {
            auto *p = reinterpret_cast<const PA_Unichar *>(fixture.c_str());
            C_TEXT text;
            text.setUTF16String(p, fixture.size());
            CUTF8String utf8;
            text.copyUTF8String(&utf8);
            auto expected = codec.to_bytes(fixture);
            assert(utf8.size() == expected.size());
            assert(std::memcmp(utf8.data(), expected.data(), expected.size()) == 0);
            C_TEXT roundtrip;
            roundtrip.setUTF8String(&utf8);
            CUTF16String result;
            roundtrip.copyUTF16String(&result);
            exact(result, fixture);
            ARRAY_TEXT values;
            values.appendUTF8String(&utf8);
            values.copyUTF16StringAtIndex(&result, 0);
            exact(result, fixture);
            values.copyUTF8StringAtIndex(&utf8, 0);
            assert(utf8.size() == expected.size());
            assert(std::memcmp(utf8.data(), expected.data(), expected.size()) == 0);

            PA_Variable array = PA_CreateVariable(eVK_ArrayUnicode);
            PA_ResizeArray(&array, 2);
            auto s = PA_CreateUnistring(const_cast<PA_Unichar *>(p));
            PA_SetStringInArray(array, 0, &s); // This SDK accepts element zero.
            auto other = PA_CreateUnistring(const_cast<PA_Unichar *>(p));
            PA_SetStringInArray(array, 1, &other);
            if (s.fString) assert(s.fString != other.fString);
            auto borrowed = PA_GetStringInArray(array, 1);
            CUTF16String copied;
            if (borrowed.fLength) copied.assign(borrowed.fString, borrowed.fLength);
            exact(copied, fixture);
            auto replacement = PA_CreateUnistring(const_cast<PA_Unichar *>(p));
            PA_SetStringInArray(array, 1, &replacement);
            PA_ResizeArray(&array, 0);
            PA_ClearVariable(&array);
            exact(copied, fixture);

            PA_Unistring scalar = PA_CreateUnistring(const_cast<PA_Unichar *>(p));
            PA_Variable variable = PA_CreateVariable(eVK_Undefined);
            PA_SetStringVariable(&variable, &scalar);
            PA_ClearVariable(&variable); // One shallow owner, not two disposals.

            PA_Unistring rejected = PA_CreateUnistring(const_cast<PA_Unichar *>(p));
            PA_Variable wrong = PA_CreateVariable(eVK_Undefined);
            PA_SetStringInArray(wrong, 0, &rejected);
            PA_DisposeUnistring(&rejected);
            auto valid = PA_CreateVariable(eVK_ArrayUnicode);
            rejected = PA_CreateUnistring(const_cast<PA_Unichar *>(p));
            PA_SetStringInArray(valid, -1, &rejected);
            PA_SetStringInArray(valid, 1, &rejected);
            PA_DisposeUnistring(&rejected);
            PA_SetStringInArray(valid, 0, nullptr);
            PA_ClearVariable(&valid);
            PA_Variable nullArray = {};
            nullArray.fType = eVK_ArrayUnicode;
            rejected = PA_CreateUnistring(const_cast<PA_Unichar *>(p));
            PA_SetStringInArray(nullArray, 0, &rejected);
            PA_DisposeUnistring(&rejected);

            ARRAY_TEXT wrapper;
            wrapper.appendUTF16String(p);
            wrapper.appendUTF16String(p);
            PA_Variable output = PA_CreateVariable(eVK_Undefined);
            unsigned char *arguments[] = {reinterpret_cast<unsigned char *>(&output)};
            wrapper.toParamAtIndex(arguments, 1);
            ARRAY_TEXT readback;
            readback.fromParamAtIndex(arguments, 1);
            readback.copyUTF16StringAtIndex(&result, 1);
            exact(result, fixture);
            PA_ClearVariable(&output);
        }
        // Actual dispatcher and full SDK, synthetic empty/error picture only.
        PA_Picture picture = nullptr;
        PA_Variable types = PA_CreateVariable(eVK_Undefined);
        PA_Variable blobs = PA_CreateVariable(eVK_Undefined);
        void *arguments[] = {&picture, &types, &blobs};
        PA_Handle result = nullptr;
        PluginBlock params = {arguments, &result, nullptr};
        PluginMain(1, &params);
        assert(types.fType == eVK_ArrayUnicode && types.uValue.fArray.fNbElements == 0);
        assert(blobs.fType == eVK_ArrayBlob && blobs.uValue.fArray.fNbElements == 0);
        PA_ClearVariable(&types);
        PA_ClearVariable(&blobs);
        PA_Unistring query = PA_CreateUnistring(nullptr);
        arguments[1] = &query;
        PluginMain(2, &params);
        assert(result == nullptr);
        PA_DisposeUnistring(&query);
        C_BLOB blob;
        const uint8_t bytes[] = {0, 1, 255};
        blob.setBytes(bytes, sizeof bytes);
        assert(blob.getBytesLength() == sizeof bytes);
        assert(std::memcmp(blob.getBytesPtr(), bytes, sizeof bytes) == 0);
        sLONG_PTR returned = 0;
        blob.setReturn(&returned);
        auto h = reinterpret_cast<PA_Handle>(returned);
        assert(PA_GetHandleSize(h) == sizeof bytes);
        assert(std::memcmp(PA_LockHandle(h), bytes, sizeof bytes) == 0);
        PA_UnlockHandle(h);
        PA_DisposeHandle(h);
        C_LONGINT number;
        number.setIntValue(42);
        assert(number.getIntValue() == 42);
    }
    assert(strings.empty() && handles.empty() && cfOwners.empty());
    assert(stringCreates == stringDisposes && handleCreates == handleDisposes);
    std::printf("PASS controls fixtures=8 strings=%zu/%zu handles=%zu/%zu "
                "picture/object/collection owners=0/0 (not exercised)\n",
                stringCreates, stringDisposes, handleCreates, handleDisposes);
}

int main(int argc, char **argv) {
    assert(argc == 2);
    gCall4D = engine;
    if (!std::strcmp(argv[1], "array-copy")) copyProbe<ARRAY_TEXT>(false);
    else if (!std::strcmp(argv[1], "array-assign")) copyProbe<ARRAY_TEXT>(true);
    else if (!std::strcmp(argv[1], "blob-copy")) copyProbe<C_BLOB>(false);
    else if (!std::strcmp(argv[1], "blob-assign")) copyProbe<C_BLOB>(true);
    else if (!std::strcmp(argv[1], "controls")) controls();
    else denied();
}
