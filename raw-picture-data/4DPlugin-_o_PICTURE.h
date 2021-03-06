/* --------------------------------------------------------------------------------
 #
 #	4DPlugin-_o_PICTURE.h
 #	source generated by 4D Plugin Wizard
 #	Project : _o_PICTURE
 #	author : miyako
 #	2020/02/20
 #  
 # --------------------------------------------------------------------------------*/

#ifndef PLUGIN__O_PICTURE_H
#define PLUGIN__O_PICTURE_H

#include "4DPluginAPI.h"

#if VERSIONMAC
#import <AppKit/AppKit.h>
#endif

#pragma mark -

void GET_PICTURE_DATA(PA_PluginParameters params);
void Get_picture_data_for_type(PA_PluginParameters params);

#ifndef uint8_t
typedef unsigned char uint8_t;
#endif

typedef uint8_t * BytePtr;
typedef BytePtr *PackagePtr;

#include <string>
#include <vector>
#include <map>

typedef std::basic_string<PA_Unichar> CUTF16String;

#endif /* PLUGIN__O_PICTURE_H */
