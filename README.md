# 4d-plugin-raw-picture-data

_o_PICTURE gives you the bytes stored in a 4D picture exactly as they are, like `PICTURE TO BLOB` but without any conversion. A 4D picture can hold its image in one or more formats; these commands list those formats and return the raw data of each one as a `BLOB`. This is useful, for example, to extract legacy PICT data from a picture without going through the QuickDraw API. The plugin only uses the 4D plugin API, so it behaves the same on macOS and Windows.

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
