#pragma once
#include "./X.h"
#include <string>

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSUserDefaults+Private.h>
#import <SystemConfiguration/SCNetwork.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

X_HIDDEN NSString *  NS(const std::string & String);
X_HIDDEN std::string CS(id OcObjectId);
X_HIDDEN id PlistToContainer(const std::string & PlistContents);
