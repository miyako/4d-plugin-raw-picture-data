# Raw-picture ownership inventory and regression

## Immutable scope and confirmed correction

Baseline: `cb584a848fd762ec564ef3ef045af8181d2bb364`.
Guidance: `miyako/skills`, `4d-skills/skills/4dplugin/SKILL.md`,
revision `e6b492fcb81e5e1a7f7db723594b420e63bf6eb9`, read through the
immutable GitHub contents API, without another checkout.

`ARRAY_TEXT` owns a heap `CUTF16StringArray`; `C_BLOB` owns a heap `CBytes`.
Their implicit copy constructors shallow-copy the owner pointer, and implicit
assignment additionally loses the destination's original owner. Destruction
then uses an already-freed object and attempts a second deletion. The correction
only deletes these four copy operations, matching the existing `C_TEXT` contract.
There is no storage/layout change, move implementation, SDK rewrite or metadata
cleanup change.

**This is a latent public-wrapper defect, not a reproduced production crash.**
Neither affected class has a production copy/assignment consumer in this
repository; neither is in any tracked project's source build membership.
All actual native consumers compile in the regression. A future caller trying
to copy either wrapper gets a compile-time error instead of two owners.
`CBytes` stores its vector by value and `C_LONGINT` stores a scalar; they remain
copyable. `C_TEXT` was already noncopyable at the immutable baseline.

## Complete tracked native and build inventory

| Surface | Membership and ownership review |
|---|---|
| `4DPlugin-_o_PICTURE.cpp`, `.h` | Dispatcher selectors 1 and 2, both manifest commands; copies only standard-library strings/maps/vectors, not owning wrappers. `Create_picture_from_PICT_data` is defined in this translation unit but has no declaration, dispatcher case or manifest command; its macOS native image path is dormant. |
| `Classes/C_TEXT.cpp`, `.h` | Active Xcode source membership, not Windows/legacy membership. Borrowed parameter descriptors become independent `CUTF16String` content. Parameter/return writes use `PA_SetUnistring`, not the scalar shallow setter. UTF conversion lengths are correct units/bytes on inspected macOS paths. Objective-C copy/path methods and their releases are compiled against deny-only substitutes, not executed or certified against Cocoa. |
| `Classes/ARRAY_TEXT.cpp`, `.h` | Dormant in all projects. Borrows array descriptors then copies text to independent C++ strings. Writes create a distinct `PA_Unistring` per element, transfer through the actual SDK setter and do not dispose after accepted transfer. Slot zero is intentionally preserved. Unchecked allocation/resize failures remain a deferred boundary. Confirmed implicit-owner-copy defect corrected. |
| `Classes/C_BLOB.cpp`, `.h` | Dormant in all projects. `C_BLOB` alone owns its `CBytes`; confirmed implicit-owner-copy defect corrected. `CBytes` owns a vector by value and creates/transfers handles on output. Existing release-before-allocation in parameter replacement remains an allocation-failure limitation; zero-length vector indexing and unrelated encoders are not certified by the nonempty BLOB control. |
| `Classes/C_LONGINT.cpp`, `.h` | Dormant in all projects, value-only scalar wrapper. |
| `Classes/C_TYPES.h` | Shared aliases, platform imports and standard-library string/vector types; no owner cleanup. |
| `4DPluginAPI.c`, `.h` | Complete unchanged bundled SDK; compiled in every project and the isolated harness. API implementation header says `rev : v14`, public header says `rev : v13`; neither is a verified upstream release. Protected, not modified. |
| `Flags.h`, `PrivateTypes.h`, `PublicTypes.h`, `EntryPoints.h` | Complete unchanged architecture, packed engine/ABI descriptors, types and selector definitions. Protected, not modified. |
| `4DPluginAPI.def` | Sole Windows export `FourDPackex`; SDK entry forwards selectors to actual `PluginMain`. No alternate plugin command export. |
| `_o_PICTURE.xcodeproj/project.pbxproj` | Source members: dispatcher, `C_TEXT.cpp`, SDK. SDK file type is Objective-C++. Deployment shell phase can sign, create a DMG and notarize. Not invoked. |
| `_o_PICTURE.v9.xcodeproj/project.pbxproj` | Source members: dispatcher and SDK. Legacy shell phase signs a bundle manifest. Not invoked. |
| `_o_PICTURE.vcxproj`, `.filters`, `.sln` | Source members: dispatcher and SDK; SDK explicitly compiled as C++ in all four configurations. `.def` supplies export. No project edits/build. |
| `manifest.json`, copied bundle manifest | Two commands: selector 1 `GET PICTURE DATA(&P;&Y;&Y)` outputs text/BLOB arrays; selector 2 `Get picture data for type(&P;&T):O` takes scalar text and returns a BLOB. Both thread-safe. No object/collection/callback command surface. |
| `.github/workflows/{bump-version,release}.yml`, `.github/scripts/*` | Existing workflows are manual only. Bump script writes/pushes version metadata; release pipeline builds, signs, packages, notarizes, tags and publishes. No dispatch, release mutation or native build performed. Existing offline release tests substitute commands. |
| `.github/workflows/ownership.yml` | New path-filtered unsigned host regression only; explicit audit branch and `master` push filters plus relevant PR changes. No signing, package, upload, install or deployment step. |
| `.github/tests/ownership/{host.mm,platform.h}`, `test_ownership.py` | New synthetic host engine, deny-only native substitutes and compile/test driver; not production plugin code or SDK replacements. |
| Other tracked files | Localized resources, plists, 4D methods/projects/data, legacy test images and prebuilt bundle are not native sources. They are not opened by the ownership harness and remain unchanged. No hidden native source is excluded by manifest membership. |

`Classes/` above means `4D Plugin API/Classes/`. Inventory is based on all
tracked paths, not only search hits. The lack of a callsite is reachability
evidence, not a general claim that an API or wrapper is safe.

### Exact bundled SDK baseline blobs

| Path below `4D Plugin API/` | Git blob |
|---|---|
| `4DPluginAPI.c` | `62f745e91d81ef2c3c901c656ea8e175d3b173e8` |
| `4DPluginAPI.h` | `528bf1d2552df08d6a8b1bc95011a9b72934ad5c` |
| `4DPluginAPI.def` | `5bbdb82fb724b6f8e307feb01d9f158b802de89d` |
| `Flags.h` | `7a5a35539f27430a3fd9cb711d6b789051316471` |
| `PrivateTypes.h` | `a3098cb662cdbc43ba574fdef72a059c4c6d1cd4` |
| `PublicTypes.h` | `9ae20b001bff9128f690fff3e6c3f873b6238333` |
| `EntryPoints.h` | `da428d5f6ca23b0a30371c7288a01d29aa3c466a` |
| `Classes/ARRAY_TEXT.cpp` | `534855e0959020ce9a66cef08f8434799c174495` |
| `Classes/ARRAY_TEXT.h` (before correction) | `cf8a458fc8519b824c726a59d346c44d4c26e845` |
| `Classes/C_BLOB.cpp` | `27bea3172ce90e4da339991c9b318a71ea8609b2` |
| `Classes/C_BLOB.h` (before correction) | `d181534e5a2e9bd46de492a040c1538ed81bf45a` |
| `Classes/C_LONGINT.cpp` | `005b83a4aec2c1466b8b219cb27ab845eb58de91` |
| `Classes/C_LONGINT.h` | `71e24df633aed7155cba1ffddc07d6a1dfc12fa9` |
| `Classes/C_TEXT.cpp` | `45ea6432dff52b681a5c6a7cea58ad5fc15df66b` |
| `Classes/C_TEXT.h` | `6967390757db569ffcd3cfea8696bf14045cc748` |
| `Classes/C_TYPES.h` | `972cf3f597a8c21881a8c9aa69bc1699455be373` |

The runner compares **every top-level bundled SDK file** to the immutable
archive, including the readme, before compiling. Only the two editable wrapper
headers change. No SDK fragment or replacement implementation is compiled.

## Target-derived contracts and explicit deferrals

* `PA_SetStringInArray` (`4DPluginAPI.c:4933-4947`) disposes the old element
  and shallow-transfers the descriptor on acceptance. It accepts a Unicode
  array with non-null `fData`, `0 <= index <= fNbElements`, non-null descriptor.
  Rejection does not consume an owner. Distinct elements need distinct owners;
  self-alias replacement is unsafe.
* `PA_GetStringInArray` (`4738-4755`) returns a borrowed descriptor; do not
  dispose/mutate it or keep it through replacement/resize. `ARRAY_TEXT` copies
  content on input instead. The regression copies borrowed content before
  replacing and clearing its source.
* `PA_SetStringVariable` (`4254-4259`) shallow-assigns. An Undefined variable
  can adopt a sole owner; creating an allocated empty scalar first would leak
  when overwritten. The plugin/wrappers have no direct scalar setter/callback
  callsite. `C_TEXT` uses the content setter, not blanket disposal removal.
* `PA_GetPictureData` (`473-484`) returns `eb.fUniString1`; neither the
  implementation nor header specifies whether metadata is owned, borrowed,
  interned, or different when a data handle is supplied. The dispatcher
  transfers enumeration metadata into the text array, ignores metadata from
  data-fetch calls, and leaves scalar enumeration metadata undisposed. These
  are **unresolved lifetime questions**, not confirmed leaks safe to patch.
  Successful metadata dispatch is not fabricated in the shim. Error output
  is poisoned and never inspected/adopted/disposed.
* `PA_GetPictureParameter` is a borrowed input. No blanket picture disposal
  is added. `PA_ReturnPicture` writes the reference into the result; the dormant
  `Create_picture_from_PICT_data` native image path needs an actual documented
  platform contract before changing image/picture cleanup. No `CPicture`,
  property/collection wrapper, asynchronous callback or converter-based picture
  `createCopy` implementation exists in this target.
* `PA_SetBlobInArray` transfers the handle and disposes the prior one on
  accepted assignment. The dispatcher already starts the BLOB element from
  Undefined, avoiding overwrite of an allocated empty BLOB.
* Protected `PA_ResizeArray` (`4428-4605`) writes the requested logical count
  even after `PA_SetHandleSize` fails. Logical bounds alone cannot certify
  physical capacity. Its BLOB-shrink branch treats a flat `PA_Blob` allocation
  as `PA_Blob**`; populated BLOB shrink/repeated selector-1 success is not
  certified. No SDK rewrite or speculative void-wrapper recovery is included.
  Allocation/resize OOM paths require a separate safe failure/reporting design;
  passing success controls is not OOM evidence.
* Protected successful property/collection getters (`587-650`) explicitly
  return owning variables requiring clear, including type mismatches.
  Matching object/collection handoffs retain owning semantics. Those APIs
  and command-result normalizers are compiled but not called by plugin code;
  failure output must not be inspected/normalized as string or cleared.
  Object/collection retain correctness and independent callback cleanup are
  not certified by zero usage counts.

## Reproducible, isolated evidence

On macOS:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 .github/tests/test_ownership.py -v
```

The same final harness is compiled twice: native sources and the **complete
unchanged SDK** from `git archive` of the immutable baseline, and current actual
sources. Archives include native paths only, not prebuilt binaries, images or
4D data. This compiles the entire actual dispatcher, dormant native image
function and all four wrappers as Objective-C++ with ASan + UBSan. No source
function is extracted or replaced; only host engine/platform implementations
are synthetic. This establishes source-level compatibility for actual consumers,
not a Windows toolchain or 4D ABI certification.

Synthetic framework headers redirect every referenced image/path/UI API
**before compilation**. Image, URL, Objective-C and graphics operations abort
if reached. Only synthetic CoreFoundation UTF conversion functions execute,
with explicit byte, code-unit and capacity contracts. The engine aborts on
unexpected selectors/suboperations. `otool -L` rejects framework imports and
permits only libobjc, libc++, libSystem and the compiler ASan runtime.
No actual user image/file, UI, platform discovery, 4D host, signing, release
tool, network fixture or private data is used.

| Same final harness case | Immutable baseline | Fixed source |
|---|---|---|
| `array-copy`, `array-assign` | Named ASan heap-use-after-free in actual `ARRAY_TEXT` destruction | Copy construction and assignment both prohibited |
| `blob-copy`, `blob-assign` | Named ASan heap-use-after-free in actual `C_BLOB` destruction | Copy construction and assignment both prohibited |
| Controls | Pass | Pass |

Controls check exact ASCII `ASCII`, BMP Japanese, supplementary `x` + U+1F600 + `y`,
and empty text for **both allocated and null empty engine strings**:
UTF-8 bytes versus UTF-16 code units, terminators, array slot zero, distinct
owners, borrowed content copies, replacement, shrink/clear, wrong kind,
negative/out-of-range index, null descriptor and null array rejection;
Undefined scalar ownership; actual array wrapper round trips; nonempty BLOB
handle return and scalar wrapper; actual selectors 1/2 for synthetic
empty/error pictures (including poisoned failure output).
Each baseline/fixed control run balances **77/77 string allocations/disposals
and 30/30 handles**. Picture/object/collection owners are explicitly **0/0, not
exercised**, rather than claimed passing refcount coverage.

On macOS LeakSanitizer is disabled; ASan/UBSan remain fail-fast and explicit
string/handle owner ledgers must empty. The four baseline copy failures stop
at the invalid destruction, so assignment's lost destination allocation is
also explained by source, not claimed as a separate LeakSanitizer result.
`OWNERSHIP_LOG_DIR` optionally writes exclusive-create named compiler/import/
control/probe logs outside the repository. Temp source archives/executables
are automatically removed. Actual Windows, real 4D execution, successful
picture metadata, native image conversion and OOM are deferred, not certified.
