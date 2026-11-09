# 4d-plugin-raw-picture-data

_o_PICTURE gives you the bytes stored in a 4D picture exactly as they are, like `PICTURE TO BLOB` but without any conversion. A 4D picture can hold its image in one or more formats; these commands list those formats and return the raw data of each one as a `BLOB`. This is useful, for example, to extract legacy PICT data from a picture without going through the QuickDraw API. The plugin only uses the 4D plugin API, so it behaves the same on macOS and Windows.

## Manual versioning and publication

**Bump version** and **Build** are separate manual Actions workflows. Neither
pushes, tags nor pull requests start a build. Select the intended branch in
Actions; all checkouts use the immutable selected `github.sha`.

1. Run **Bump version** on that branch with `patch`, `minor` or `major`. It
   validates source metadata, makes one source-only commit directly on the
   selected SHA, and pushes only the selected branch without tags. The required
   executable pre-push guard rejects a changed advertised branch (including
   rewind, deletion and an already-identical result). A stale selection fails;
   select the current branch again rather than forcing a push.
2. Separately run **Build** on the updated branch. It has **no inputs** beyond
   Actions' branch selector. Source `X.Y.Z` determines `vX.Y.Z`,
   `_o_PICTURE-X.Y.Z.zip` and `_o_PICTURE-X.Y.Z.dmg`; no existing tag is selected.
   Publication is serialized repository-wide across branches, without cancelling
   an in-progress run.

The existing Windows x64 Release build remains first (MSBuild v143 / Windows SDK
10.0 overrides; the project itself remains v140). macOS remains the Default
target, universal arm64 + x86_64, deployment target 11.5. Exact fresh Windows
output and downloaded artifact paths are required. The macOS binary, signature,
copied plist and copied English strings are invalidated before rebuilding and
verified against source afterwards, including UTF-16/binary built strings.
The explicit no-i386 gate remains in addition to required slices. Committed
QuickLook/resources, Windows artifacts and runtime libraries are not removed
by the macOS cleanup. Signing, strict signature verification, both Accepted
notarizations and DMG stapling still precede publication; a failed notarization
command cannot succeed merely by emitting an Accepted payload.

The existing secret **names** are unchanged:
`APPLE_DEVELOPER_ID_CERTIFICATE`, `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`,
`KEYCHAIN_PASSWORD`, `NOTARYTOOL_APPLE_ID`, `NOTARYTOOL_TEAM_ID`,
`NOTARYTOOL_PASSWORD`.

### Source authority and migration evidence

The original bump header at
[`b032ab0`](https://github.com/miyako/4d-plugin-raw-picture-data/commit/b032ab062f41c97aca46c16e849a6339822fd3fc)
explicitly promises to write the same version into
`MARKETING_VERSION`/**`CURRENT_PROJECT_VERSION`** and
`CFBundleShortVersionString`/**`CFBundleVersion`**. That coordinated promise
overrides its buggy marketing-first/current-only-fallback body. Rename-follow
history for the workflow and source metadata leads to this modernization commit
and the original `4fa8af6`; no later version-policy change exists.

The three active configurations in `_o_PICTURE.xcodeproj/project.pbxproj` and
source `Info.plist` already agree on **1.0.1**. The project actually copies
`English.lproj/InfoPlist.strings` into Resources, where stale `1.0` values override
the display version. This migration repairs only its two version tokens to the
existing **1.0.1** authority, with no intake increment. Its CR-only bytes,
copyright, file mode and other content remain intact. The optional absent
`CFBundleVersion` stays absent. `_o_PICTURE.v9.xcodeproj`, prebuilt bundles,
dependencies, Windows projects, 4D data/schema and counters are not version
inputs.

Future bumps update only the three explicit source paths above. Strict
validation rejects drift, duplicate plist/localized keys (quoted, unquoted or
inline), unsupported serialization, unknown/cyclic references and invalid
versions **before writing anything**. Supported version references, optional
absent keys, BOMs, CR/LF/CRLF and mixed line endings, modes and unrelated bytes
are preserved.

Helpers and full offline suites are adapted from exact committed prior art:
[`native-encoding-detection@c42ca56`](https://github.com/miyako/4d-plugin-native-encoding-detection/commit/c42ca565857f674bde5ea6ed3435c87375eda4a7)
(coordinated six-config metadata, strict localized tokenizer, fail-closed Windows
cleanup) and
[`file-information@1984897`](https://github.com/miyako/4d-plugin-file-information/commit/19848973601acfd3a2b5070230fa40cdc7e4edb2)
(three configurations, built strings encodings and explicit i386 rejection).
The independent-build contracts in
[`common-string-algorithm@2606a68`](https://github.com/miyako/4d-plugin-common-string-algorithm/commit/2606a68201866ec9fcbb38b51462d79215f504ef)
and corrected
[`window-button@3f14fac`](https://github.com/miyako/4d-plugin-window-button/commit/3f14facb9aaaaff0e22eeb8e07531163680c3a8a)
were inspected but do not override this repository's explicit coordinated header.

### Create-only publication and recovery

Build checks the exact remote tag and authenticated, fully paginated release
lists (including drafts) both before native work and after all native gates.
Authentication, 404, network, malformed data and later-page failures stop the
run; they are never interpreted as availability. It then separately POSTs a
**new** tag ref at the selected SHA, verifies it remotely, POSTs a **new public,
non-prerelease** release named after the tag with the original empty body/no
generated notes, and uploads each asset to the newly returned release ID.
Concurrent creation, even at the same SHA, is an error. Existing releases/tags
are never reused, overwritten, deleted or clobbered.

There is **no automatic rollback, retry or repair**. A failed POST may have
succeeded remotely: inspect the run's selected SHA, exact tag, release ID and
asset list before taking any action. Tag verification/release creation failures
retain any tag; upload failures retain the tag, release and every earlier
uploaded asset. Never rerun hoping to overwrite that state. Resolve incomplete
publication deliberately outside this workflow, or bump source and publish a
new version. Branch-push verification failures likewise require inspecting the
remote branch before another bump.

Offline checks (no native tools or publication):

```sh
actionlint
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .github/tests -v
```

The suite uses disposable bare Git repositories, mocked GitHub responses,
closed-PATH native command stubs and PowerShell shell fixtures; it never
executes MSBuild, Xcode, signing, notarization, 4D or real publication.

| Command | Returns | Purpose |
|---|---|---|
| [GET PICTURE DATA](#get-picture-data) | `ARRAY TEXT`, `ARRAY BLOB` (in parameters 2 and 3) | List every format stored in a picture, with its raw data |
| [Get picture data for type](#get-picture-data-for-type) | `BLOB` | Get the raw data of one format, by type name |

**Platforms:** macOS (Apple silicon and Intel), Windows (64-bit)

More background: [miyako.github.io](https://miyako.github.io/2020/02/20/4d-plugin-raw-picture-data.html)

---

## Requirements & platform notes

- **All parameters are mandatory.** `GET PICTURE DATA(&P;&Y;&Y)` and `Get picture data for type(&P;&T):O` in the manifest.
- **Nothing is converted.** You get the bytes 4D stores for each format, in that format. Use 4D's picture commands if you need a picture back.
- **Failure is silent, not a 4D error.** A picture with no data gives empty arrays; a type that isn't in the picture gives an empty `BLOB`.
- **Preemptive processes:** the manifest declares both commands thread-safe.

---

## GET PICTURE DATA

### Syntax

```
GET PICTURE DATA ( picture ; types ; data )
```

| Parameter | Type | Description |
|---|---|---|
| `picture` | Picture | The picture to read |
| `types` | ARRAY TEXT | Receives the type of each stored format |
| `data` | ARRAY BLOB | Receives the raw data of each stored format |
| Result | — | None. The result is written into `types` and `data` |

### Description

`GET PICTURE DATA` asks 4D for each format stored in `picture`, in order, and fills both arrays with one element per format: `types{$i}` describes the format and `data{$i}` holds its bytes. Both arrays are resized to the number of formats (0 if the picture is empty).

A type string can list several names for the same format, separated by `;`. These are the names [`Get picture data for type`](#get-picture-data-for-type) matches against.

`types` must be a text array and `data` a BLOB array, or undefined variables (which become arrays of those types). If either is declared as another array type, neither array is changed.

### Example

From the plugin's own test method (`TEST.4dm`):

```4d
$path:=Get 4D folder:C485(Current resources folder:K5:16)+"PICT"+Folder separator:K24:12

READ PICTURE FILE:C678($path+"676.pict";$PICT;*)

  //these 2 use 4D plugin API, they are platform agnostic

GET PICTURE DATA ($PICT;$arrType;$arrData)

$data:=Get picture data for type ($PICT;".pict")
```

Save every stored format to a file:

```4d
ARRAY TEXT($types;0)
ARRAY BLOB($data;0)
GET PICTURE DATA($picture;$types;$data)

For ($i;1;Size of array($types))
	BLOB TO DOCUMENT(System folder(Desktop)+"format"+String($i)+".bin";$data{$i})
End for 
```

---

## Get picture data for type

### Syntax

```
Get picture data for type ( picture ; type ) → data
```

| Parameter | Type | Description |
|---|---|---|
| `picture` | Picture | The picture to read |
| `type` | Text | The type name to look for, e.g. `".pict"` |
| Result | BLOB | The raw data of that format, or an empty BLOB |

### Description

`Get picture data for type` reads the type of every format stored in `picture`, splits each type string at `;`, and looks for an exact, case-sensitive match of `type`. If several formats share the name, the first one wins. It returns that format's raw bytes, or an empty `BLOB` if no format matches.

Call [`GET PICTURE DATA`](#get-picture-data) first if you don't know which type names a picture uses.

### Example

From the plugin's own test method (`TEST.4dm`):

```4d
$data:=Get picture data for type ($PICT;".pict")
```

Check the result:

```4d
$data:=Get picture data for type($picture;".pict")
If (BLOB size($data)=0)
	ALERT("This picture has no PICT data.")
End if 
```

---

## Error handling & troubleshooting

- **Empty BLOB from `Get picture data for type`.** No stored format has that type name. List the names with `GET PICTURE DATA`; matching is exact and case-sensitive.
- **The arrays stay unchanged.** One of them was declared with another type (for example `ARRAY PICTURE`). Declare `ARRAY TEXT` and `ARRAY BLOB`, or pass undefined variables.
- **Empty arrays.** The picture is empty, or 4D reported an error for its first format.

---

## Quick reference

```4d
ARRAY TEXT($types;0)
ARRAY BLOB($data;0)
GET PICTURE DATA($picture;$types;$data)   // one element per stored format
$pict:=Get picture data for type($picture;".pict")
```
