#include "./X.hpp"
#include "./X_Command.hpp"
#include "./X_OC.hpp"
#include "./X_IO.hpp"
#include "./X_Chrono.hpp"
#include "./X_Fishhook.h"
#include "./iOS/Limits.hpp"
#include "./scripts/Lua_System.hpp"
#include "./scripts/main_lua.hpp"
#include <thread>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <array>
#include <dlfcn.h>

using namespace std;

int main(int argc, char *argv[], char *envp[]) {
	xCommandLine Cmd = { argc, argv, {
		{ 'l',   "lua",              "lua",                  true },
		{ 'f',   "lua_file",         "lua_file",             true },
		{ 'p',   "plist",            "plist_file",           true },
		{ 'i',   "ipa",              "ipa_file",             true },
		{ 'b',   "path-by-bundle",   "path-by-bundle",       true },
		{ 0,     "gw",               "get_high_water_mark",  true },
		{ 0,     "sw",               "set_high_water_mark",  true },
	}};

	auto OptLua = Cmd["lua"];
	if (OptLua()) {
		auto LuaScript = *OptLua;
		main_lua_init(1, LuaScript);
		while(!PublicStopFlag) {
			std::this_thread::sleep_for(50ms);
		}
		main_lua_uninit();
		return 0;
	}

	auto OptLuaFile = Cmd["lua_file"];
	if (OptLuaFile()) {
		auto LuaScript = ReadFile(OptLuaFile->c_str());
		main_lua_init(1, LuaScript);
		while(!PublicStopFlag) {
			std::this_thread::sleep_for(50ms);
		}
		main_lua_uninit();
		return 0;
	}

	auto OptPlistFile = Cmd["plist_file"];
	if (OptPlistFile()) {
		auto PlistContents = ReadFile(OptPlistFile->c_str());
		auto Container = PlistToContainer(PlistContents);
		cout << XS(Container) << endl;
		return 0;
	}

	auto OptGetHightWaterMark = Cmd["get_high_water_mark"];
	if (OptGetHightWaterMark()) {
		int32_t pid = atoll(OptGetHightWaterMark->c_str());
		int limit = GetHightWaterMark(pid);
		cout << "HighWaterMark for pid=" << pid << " is " << limit << endl;
		return 0;
	}

	auto OptSetHightWaterMark = Cmd["set_high_water_mark"];
	if (OptSetHightWaterMark()) {
		int32_t pid = atoll(OptSetHightWaterMark->c_str());
		int oldLimit = GetHightWaterMark(pid);
		int limit = 16 * 1024 * 1024;
		if (limit <= oldLimit) {
			cout << "Set HighWaterMark for pid=" << pid << " from " << oldLimit << " which is larger or equal than target value (" << limit <<  ")" << endl;
			cout << "Operation cancelled" << endl;
			return 0;
		}
		SetHighWaterMark(pid, limit);
		int newLimit = GetHightWaterMark(pid);
		cout << "Set HighWaterMark for pid=" << pid << " from " << oldLimit << " to " << limit << ", updatedValue=" << newLimit << endl;
		return 0;
	}

	auto OptIpaFile = Cmd["ipa_file"];
	if (OptIpaFile()) {
		main_lua_init(1); // init lua logger only
		cout << "IpaInstall: " << IpaInstall(*OptIpaFile) << endl;
		main_lua_uninit();
		return 0;
	}

	auto OptPathByBundle = Cmd["path-by-bundle"];
	if (OptPathByBundle()) {
		auto Uuid = GetIpaUuidByBundleId(*OptPathByBundle);
		auto DataPath = std::filesystem::path{"/private/var/mobile/Containers/Data/Application"} / Uuid;
		cout << "Bundle Id: " << *OptPathByBundle << endl;
		cout << "Uuid: " << Uuid << endl;

		auto DataDirectories = GetIpaDataDirectories(*OptPathByBundle);
		for (auto & Dir : DataDirectories) {
			cout << "DataDir: " << Dir << endl;
		}
		return 0;
	}

	cout << Cmd.DescribeOptions() << endl;
	return -1;
}
