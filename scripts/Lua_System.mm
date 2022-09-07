#include "./Lua_All.hpp"
#include "../X_OC.hpp"
#include "../3rd/minizip/mz_compat.h"
#include <thread>
#include <chrono>
#include <algorithm>
#include <filesystem>
#include <string>
#include <regex>
#include <unistd.h>
#include <objc/runtime.h>
#include <dlfcn.h>
#include <fstream>

#define kIdentifierKey @"CFBundleIdentifier"
#define kAppType @"User"
#define kAppTypeKey @"ApplicationType"

typedef void (*MobileInstallationCallback)(CFDictionaryRef information);
typedef int (*MobileInstallationInstall)(CFStringRef path, CFDictionaryRef parameters, MobileInstallationCallback callback, CFStringRef backpath);
#define MI_PATH "/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation"

static void mobileInstallationStatusCallback(CFDictionaryRef information) {
	NSDictionary *installInfo = (__bridge NSDictionary *)information;
	NSNumber *percentComplete = [installInfo objectForKey:@"PercentComplete"];
	NSString *installStatus = [installInfo objectForKey:@"Status"];

	if (installStatus) {
		// Use NSRegularExpression to split up the Apple-provided PascalCase status string into individual words with spaces
		NSRegularExpression *pascalCaseSplitterRegex = [NSRegularExpression regularExpressionWithPattern:@"([a-z])([A-Z])" options:0 error:nil];
		installStatus = [pascalCaseSplitterRegex stringByReplacingMatchesInString:installStatus options:0 range:NSMakeRange(0, [installStatus length]) withTemplate:@"$1 $2"];

		// Capitalise only the first character in the resulting string
		// TODO: Figure out a better/cleaner way to do this. This was simply the first method that came to my head after thinking about it for all of like, 30 seconds.
		installStatus = [NSString stringWithFormat:@"%@%@", [[installStatus substringToIndex:1] uppercaseString], [[installStatus substringWithRange:NSMakeRange(1, [installStatus length] - 1)] lowercaseString]];

		// Print status
		// Yes, I went through all this extra effort just so the user can look at some pretty strings. No, there is (probably) nothing wrong with me. ;P
		printf("%ld%% - %s…\n", (long)[percentComplete integerValue], [installStatus UTF8String]);
	}
}

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options error:(NSError**)error;
- (BOOL)uninstallApplication:(NSString *)identifier withOptions:(NSDictionary *)options;
@end

typedef int(*FnSBSLaunchApplicationWithIdentifier)(CFStringRef identifier, bool flag);
bool AppLaunch(const std::string & BundleId)
{
    void *spbsHandle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_GLOBAL);
    if (!spbsHandle) {
        LuaLogger.E("AppLaunch: Failed to load spring board service");
        return false;
    }
    auto AutoClose = xScopeGuard {[&]{ dlclose(spbsHandle); }};

    CFStringRef identifier = CFStringCreateWithCString(kCFAllocatorDefault, BundleId.c_str(), kCFStringEncodingUTF8);
    if (!identifier) {
        LuaLogger.E("AppLaunch: Unable to parse bundle identifier");
        return false;
    }

    auto SBSLaunchApplicationWithIdentifier = (FnSBSLaunchApplicationWithIdentifier)dlsym(spbsHandle, "SBSLaunchApplicationWithIdentifier");
    int result = SBSLaunchApplicationWithIdentifier(identifier, FALSE);
    if (result) {
        LuaLogger.E("AppLaunch: Unable to lanch application");
        return false;
    }
    return true;
}

typedef int (*FnSBSOpenSensitiveURLAndUnlock)(CFURLRef url, char flags);
bool AppLaunchUrl(const std::string & UrlString)
{
    void *spbsHandle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_GLOBAL);
    if (!spbsHandle) {
        LuaLogger.E("AppLaunch: Failed to load spring board service");
        return false;
    }
    auto AutoClose = xScopeGuard {[&]{ dlclose(spbsHandle); }};

    NSURL * Url = [NSURL URLWithString: NS(UrlString)];

    CFURLRef UrlRef = (__bridge CFURLRef)(Url);

    auto SBSOpenSensitiveURLAndUnlock = (FnSBSOpenSensitiveURLAndUnlock)dlsym(spbsHandle, "SBSOpenSensitiveURLAndUnlock");
    int result = SBSOpenSensitiveURLAndUnlock(UrlRef, 0);
    if (!result) {
        LuaLogger.E("AppLaunch: Unable to lanch application");
        return false;
    }
    return true;
}

std::string IpaInstall(const std::string & IpaPath)
{
    auto unzip = unzOpen(IpaPath.c_str());
    if (!unzip) {
        LuaLogger.E("Failed to open ipa file");
        return {};
    }
    auto AutoClose = xScopeGuard( [&]{unzClose(Steal(unzip));} );

    std::regex AppNameReg { "^Payload/[-_a-zA-Z0-9]+\\.app/$" };
    size_t AppNamePrefixLength = SafeLength("Payload/");
    size_t AppNamePosefixLength = SafeLength("/");
    std::string AppPath;
    std::string AppName;

    std::regex InfoPlistReg { "^Payload/[-_a-zA-Z0-9]+\\.app/Info.plist$" };
    std::string InfoPlistName;
    std::string InfoPlistContents;

    for(int ret = unzGoToFirstFile(unzip); ret == UNZ_OK; ret = unzGoToNextFile(unzip)) {
        unz_file_info fileInfo = {};
        char FilenameBuffer[1024];
        if (UNZ_OK != unzGetCurrentFileInfo(unzip, &fileInfo, FilenameBuffer, sizeof(FilenameBuffer), NULL, 0, NULL, 0)) {
            LuaLogger.E("Failed to get file info");
            break;
        }
        auto Filename = std::string(FilenameBuffer, fileInfo.size_filename);

        if (AppName.empty()) {
            std::smatch AppNameCheck;
            if (std::regex_match(Filename, AppNameCheck, AppNameReg)) {
                AppPath = Filename;
                AppName = Filename.substr(AppNamePrefixLength, fileInfo.size_filename - AppNamePrefixLength - AppNamePosefixLength);
                continue;
            }
        }
        if (InfoPlistName.empty()) {
            std::smatch InfoPlistCheck;
            if (std::regex_match(Filename, InfoPlistCheck, InfoPlistReg)) {
                InfoPlistName = Filename;
                InfoPlistContents.resize(fileInfo.uncompressed_size);
                auto OpenResult = unzOpenCurrentFile(unzip);
                if (UNZ_OK != OpenResult) {
                    LuaLogger.E("Failed to open InfoPlist File: %s, errorCode=%i, expectedFileSize=%zi", InfoPlistName.c_str(), OpenResult, size_t(fileInfo.uncompressed_size));
                    return {};
                }
                auto AutoCloseInfoPlist = xScopeGuard{[&]{ unzCloseCurrentFile(unzip); }};
                unzReadCurrentFile(unzip, InfoPlistContents.data(), fileInfo.uncompressed_size);
                continue;
            }
        }
    }
    if (AppName.empty() || InfoPlistName.empty() || 0 != InfoPlistName.find(AppPath.c_str())) {
        LuaLogger.E("Appname or InfoPlist missing");
        return {};
    }

    NSData * InfoData = [NS(InfoPlistContents) dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary * InfoDict = [NSPropertyListSerialization propertyListWithData:InfoData options:NSPropertyListImmutable format:nil error:nil];

    if (![InfoDict isKindOfClass: [NSDictionary class]]) {
        LuaLogger.E("Invalid Plist");
        return {};
    }
    NSString * AppBundleId = [InfoDict objectForKey: kIdentifierKey];
    if (!AppBundleId || ![AppBundleId isKindOfClass: [NSString class]]) {
        LuaLogger.E("Invalid AppBundleId");
        return {};
    }
	if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
        Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
        if (LSApplicationWorkspace_class == nil) {
            LuaLogger.E("No LSApplicationWorkspace class found");
            return {};
        }
        LSApplicationWorkspace *workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
        if (workspace == nil) {
            LuaLogger.E("No LSApplicationWorkspace found");
            return {};
        }
        @try {
            NSString * installPath =  NS(IpaPath);
            NSDictionary *options = [NSDictionary dictionaryWithObject:AppBundleId forKey:kIdentifierKey];
            [workspace installApplication:[NSURL fileURLWithPath:installPath] withOptions:options];
        } @catch (NSException *e) {
            LuaLogger.E("Exception during installation: %s", ToString(e).c_str());
            return {};
        }
    }
    else {
       // Use MobileInstallationInstall on iOS 5〜7
        void *image = dlopen(MI_PATH, RTLD_LAZY);
        if (image == NULL) {
            LuaLogger.E("Failed to retrieve MobileInstallation.\n");
            return {};
        }

        MobileInstallationInstall installHandle = (MobileInstallationInstall) dlsym(image, "MobileInstallationInstall");
        if (installHandle == NULL) {
            LuaLogger.E("Failed to retrieve the MobileInstallationInstall function.\n");
            return {};
        }

        // Install app
        NSDictionary *options = [NSDictionary dictionaryWithObject:kAppType forKey:kAppTypeKey];
        NSString * installPath =  NS(IpaPath);
        if (installHandle((__bridge CFStringRef) installPath, (__bridge CFDictionaryRef) options, &mobileInstallationStatusCallback, (__bridge CFStringRef) installPath)) {
            LuaLogger.E("dysym install failed");
            return {};
        }
    }
    return ToString(AppBundleId);
}

std::string GenerateUuid()
{
    CFUUIDRef uuid_ref = CFUUIDCreate(NULL);
    CFStringRef uuid_string_ref= CFUUIDCreateString(NULL, uuid_ref);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuid_string_ref];
    CFRelease(uuid_ref);
    CFRelease(uuid_string_ref);
    return ToString([uuid lowercaseString]);
}

/*********************/

int Lua_SleepMS(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [TimeoutMS] = W.Pop<uint64_t>();
    std::this_thread::sleep_for(std::chrono::milliseconds(TimeoutMS));
    return W.Return();
}

int Lua_Remove(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Filename] = W.Get<const char *>();
    std::error_code ErroCode;
    std::filesystem::remove_all(Filename, ErroCode);
    W.PopN(1);
    return W.Return();
}

int Lua_IpaInstall(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Filename] = W.Pop<std::string>();
    return W.Return(IpaInstall(Filename));
}

int Lua_IpaLaunchByBundleId(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [BundleId] = W.Pop<std::string>();
    return W.Return(AppLaunch(BundleId));
}

int Lua_IpaLaunchBySchemeUrl(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [SchemeUrl] = W.Pop<std::string>();
    return W.Return(AppLaunchUrl(SchemeUrl));
}

int Lua_Uuid(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    return W.Return(GenerateUuid());
}

int Lua_MakeFile(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Filename, Contents] = W.Pop<std::string, std::string>();

    std::ofstream File(Filename.c_str(), std::ios_base::trunc | std::ios_base::binary);
    if (!File) {
        W.Error("Failed to open file");
        return W.Return(false);
    }
    File << Contents;
    return W.Return(true);
}
