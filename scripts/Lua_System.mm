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
		LuaLogger.I("MobileInstallationStatusCallback: %ld%% - %s…", (long)[percentComplete integerValue], [installStatus UTF8String]);
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

static bool doesProcessAtPIDExist(pid_t pid) {
	// kill() returns 0 when the process exists, and -1 if the process does not.
	// TODO: This currently does not take into account a possible edge-case where a user can launch one instance of appinst as root, and another appinst instance as a non-privileged user.
	// In such a case, if the non-privileged appinst attempts to kill(), it would return -1 due to failing the permission check, therefore resulting in a false positive.
	return (kill(pid, 0) == 0);
}

static bool isSafeToDeleteAppInstTemporaryDirectory(NSString *workPath) {
	// There is no point in running multiple instances of appinst, as app installation on iOS can only happen one app at a time.
	// … That being said, some people may still try to do so anyway — iOS /does/ gracefully handle such a state, and will simply wait for an existing install session lock to release before proceeding.
	// However, appinst's temporary directory self-cleanup code prior to appinst 1.2 could potentially result in a slight issue if the user tries to run multiple appinst instances.
	// If you launch two appinst instances in quick enough succession, both will fail to install due to their temporary IPA copies having been deleted by each other.
	// ※ If you don't do it quickly, then nothing will really happen, because the file handle would have already been opened by MobileInstallation / LSApplicationWorkSpace, and the deletion wouldn't really take effect until the file handle was closed.
	// But in the interest of making appinst as robust as I possibly can, here's some code to handle this potential edge-case.

	// Build a list of all PID files in the temporary directory
	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workPath error:nil];
	NSArray *pidFiles = [dirContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.pid'"]];
	for (NSString *pidFile in pidFiles) {
		// Read the PID file contents and assign it to a pid_t
		NSString *pidFilePath = [workPath stringByAppendingPathComponent:pidFile];
		pid_t pidToCheck = [[NSString stringWithContentsOfFile:pidFilePath encoding:NSUTF8StringEncoding error:nil] intValue];
		if (pidToCheck == 0) {
			// If the resulting pid_t ends up as 0, something went horribly wrong while parsing the contents of the PID file.
			// We'll just treat this failed state as if there are other active instances of appinst, just in case.
			LuaLogger.E("IsSafeToDeleteAppInstTemporaryDirectory: Failed to read the PID from %s! Proceeding as if there are other active instances of appinst…", [pidFilePath UTF8String]);
			return false;
		}
		if (doesProcessAtPIDExist(pidToCheck)) {
			// If the PID exists, this means that there is another appinst instance in an active install session.
			// This also takes into account PID files left over by an appinst that crashed or was otherwise interrupted, and therefore didn't get to clean up after itself
			LuaLogger.E("IsSafeToDeleteAppInstTemporaryDirectory: Another instance of appinst seems to be in an active install session. Proceeding without deleting the temporary directory…");
			return false;
		}
	}
	return true;
}

static NSString * GenerateSessionId() {
	static const char kRandomAlphabet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	static constexpr size_t kRandomLength = 32;
	NSMutableString *sessionID = [NSMutableString stringWithCapacity:kRandomLength];
	for (int i = 0; i < kRandomLength; i++) {
		[sessionID appendFormat: @"%C", kRandomAlphabet[arc4random_uniform(SafeLength(kRandomAlphabet))]];
	}
	return sessionID;
}

static NSString * GetBundleId(const std::string & IpaPath)
{
    auto unzip = unzOpen(IpaPath.c_str());
    if (!unzip) {
        LuaLogger.E("GetBundleId: Failed to open ipa file");
        return nil;
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
            LuaLogger.E("GetBundleId: Failed to get file info");
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
                    LuaLogger.E("GetBundleId: Failed to open InfoPlist File: %s, errorCode=%i, expectedFileSize=%zi", InfoPlistName.c_str(), OpenResult, size_t(fileInfo.uncompressed_size));
                    return nil;
                }
                auto AutoCloseInfoPlist = xScopeGuard{[&]{ unzCloseCurrentFile(unzip); }};
                unzReadCurrentFile(unzip, InfoPlistContents.data(), fileInfo.uncompressed_size);
                continue;
            }
        }
    }
	NSData * InfoData = [NS(InfoPlistContents) dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary * InfoDict = [NSPropertyListSerialization propertyListWithData:InfoData options:NSPropertyListImmutable format:nil error:nil];

    if (![InfoDict isKindOfClass: [NSDictionary class]]) {
        LuaLogger.E("GetBundleId: Invalid Plist");
        return nil;
    }
    NSString * AppBundleId = [InfoDict objectForKey: kIdentifierKey];
    if (!AppBundleId || ![AppBundleId isKindOfClass: [NSString class]]) {
        LuaLogger.E("GetBundleId: Invalid AppBundleId");
		return nil;
    }
	return AppBundleId;
}

std::string IpaInstall(const std::string & IpaPath)
{
	NSString *appIdentifier = GetBundleId(IpaPath);
	if (appIdentifier == nil) {
		LuaLogger.E("IpaInstall: Failed to resolve app identifier for the specified IPA file.");
		return {};
	}

	pid_t currentPID = getpid();
	NSString *sessionID = GenerateSessionId();
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *workPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"xl.appinst"];
	NSString *installName = [NSString stringWithFormat:@"appinst-session-%@.ipa", sessionID];
	NSString *installPath = [workPath stringByAppendingPathComponent:installName];
	NSString *pidFilePath = [workPath stringByAppendingPathComponent:[NSString stringWithFormat:@"appinst-session-%@.pid", sessionID]];

	auto AutoCleanup = xScopeGuard([&]{
		// Clean up appinst PID file for current session ID
		if ([fileManager fileExistsAtPath:pidFilePath] && [fileManager isDeletableFileAtPath:pidFilePath]) {
			LuaLogger.I("IpaInstall: Cleaning up appinst session ID %s (PID %d)…", [sessionID UTF8String], currentPID);
			[fileManager removeItemAtPath:pidFilePath error:nil];
		}
		// Clean up temporary copied IPA
		if ([fileManager fileExistsAtPath:installPath] && [fileManager isDeletableFileAtPath:installPath]) {
			LuaLogger.I("IpaInstall: Cleaning up temporary files…");
			[fileManager removeItemAtPath:installPath error:nil];
		}
		// Clean up temporary directory
		if ([fileManager fileExistsAtPath:workPath] && [fileManager isDeletableFileAtPath:workPath] && isSafeToDeleteAppInstTemporaryDirectory(workPath)) {
			LuaLogger.I("IpaInstall: Deleting temporary directory…");
			[fileManager removeItemAtPath:workPath error:nil];
		}
	});

	LuaLogger.I("IpaInstall: Install ipa: workpath:%s", XS(workPath).c_str());
	// If there was a leftover temporary directory from a previous run, clean it up
	if ([fileManager fileExistsAtPath:workPath] && isSafeToDeleteAppInstTemporaryDirectory(workPath)) {
		if (![fileManager removeItemAtPath:workPath error:nil]) {
			// This theoretically should never happen, now that appinst sets 0777 directory permissions for its temporary directory as of version 1.2.
			// That, and the temporary directory is also different as of 1.2, too, so even if an older version of appinst was run as root, it should not affect appinst 1.2.
			LuaLogger.E("IpaInstall: Failed to delete leftover temporary directory at %s, continuing anyway.", [workPath UTF8String]);
			LuaLogger.E("IpaInstall: This can happen if the previous temporary directory was created by the root user.");
			return {};
		} else {
			LuaLogger.I("IpaInstall: Deleting leftover temporary directory…");
		}
	}

	NSDictionary *workPathDirectoryPermissions = [NSDictionary dictionaryWithObject:@0777 forKey:NSFilePosixPermissions];
	if (![fileManager createDirectoryAtPath:workPath withIntermediateDirectories:YES attributes:workPathDirectoryPermissions error:nil]) {
		LuaLogger.E("IpaInstall: Failed to create temporary directory.");
		return {};
	}

	// Write the current appinst PID to a file corresponding to the session ID
	// This is only used in isSafeToDeleteAppInstTemporaryDirectory() — see the comments in that function for more information.
	if (![[NSString stringWithFormat:@"%d", currentPID] writeToFile:pidFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
		// If we fail to write the PID, just ignore it and continue on. It's very unlikely that users will even run into the rare issue that this code is a fix for, anyway.
		LuaLogger.E("IpaInstall: Failed to write PID file to %s, continuing anyway.", [pidFilePath UTF8String]);
		return {};
	}

	if ([fileManager fileExistsAtPath:installPath]) {
			// It is extremely unlikely (almost impossible) for a session ID collision to occur, but if it does, we'll delete the conflicting IPA.
			if (![fileManager removeItemAtPath:installPath error:nil]) {
				// … It's also possible (but even /more/ unlikely) that this will fail.
				// If this somehow happens, just instruct the user to try again. That will give them a different, non-conflicting session ID.
				LuaLogger.E("IpaInstall: Failed to delete conflicting leftover temporary files from a previous appinst session at %s. Please try running appinst again.", [installPath UTF8String]);
				return {};
			}
		}
	if (![fileManager copyItemAtPath:NS(IpaPath) toPath:installPath error:nil]) {
		LuaLogger.E("IpaInstall: Failed to copy the specified IPA to the temporary directory. Do you have enough free disk space?");
		return {};
	}

	BOOL isInstalled = NO;
	LuaLogger.I("IpaInstall: Installing \"%s\"…", [appIdentifier UTF8String]);
	if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
		// Use LSApplicationWorkspace on iOS 8 and above
		Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
		if (LSApplicationWorkspace_class == nil) {
			LuaLogger.E("IpaInstall: Failed to get class: LSApplicationWorkspace");
			return {};
		}

		LSApplicationWorkspace *workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
		if (workspace == nil) {
			LuaLogger.E("IpaInstall: Failed to get the default workspace.");
			return {};
		}

		// Install app
		NSDictionary *options = [NSDictionary dictionaryWithObject:appIdentifier forKey:kIdentifierKey];
		@try {
			if ([workspace installApplication:[NSURL fileURLWithPath:installPath] withOptions:options]) {
				isInstalled = YES;
			} else {
				LuaLogger.E("IpaInstall: workspace installApplication resturns unknown error");
			}
		} @catch (NSException *e) {
			LuaLogger.E("IpaInstall: Installation exception: %s", XS(e).c_str());
			return {};
		}
	} else {
		// Use MobileInstallationInstall on iOS 5〜7
		void *image = dlopen(MI_PATH, RTLD_LAZY);
		if (image == NULL) {
			LuaLogger.E("IpaInstall: Failed to retrieve MobileInstallation.");
			return {};
		}

		MobileInstallationInstall installHandle = (MobileInstallationInstall) dlsym(image, "MobileInstallationInstall");
		if (installHandle == NULL) {
			LuaLogger.E("IpaInstall: Failed to retrieve the MobileInstallationInstall function.");
			return {};
		}

		// Install app
		NSDictionary *options = [NSDictionary dictionaryWithObject:kAppType forKey:kAppTypeKey];
		if (installHandle((__bridge CFStringRef) installPath, (__bridge CFDictionaryRef) options, &mobileInstallationStatusCallback, (__bridge CFStringRef) installPath) == 0) {
			isInstalled = YES;
		}
		LuaLogger.E("IpaInstall: MobileInstallationInstall resturns unknown error");
	}
	if (!isInstalled) {
		return {};
	}
	return XS(appIdentifier);
}

std::string GenerateUuid()
{
	CFUUIDRef uuid_ref = CFUUIDCreate(NULL);
	CFStringRef uuid_string_ref= CFUUIDCreateString(NULL, uuid_ref);
	NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuid_string_ref];
	CFRelease(uuid_ref);
	CFRelease(uuid_string_ref);
	return XS([uuid lowercaseString]);
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
