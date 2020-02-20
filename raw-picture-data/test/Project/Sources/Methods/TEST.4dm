//%attributes = {}
$path:=Get 4D folder:C485(Current resources folder:K5:16)+"PICT"+Folder separator:K24:12

READ PICTURE FILE:C678($path+"676.pict";$PICT;*)

  //these 2 use 4D plugin API, they are platform agnostic

GET PICTURE DATA ($PICT;$arrType;$arrData)

$data:=Get picture data for type ($PICT;".pict")

  //this one is for Mac only

$picture:=Create picture from PICT data ($data)

SET PICTURE TO PASTEBOARD:C521($picture)