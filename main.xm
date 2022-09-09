#include "./X.hpp"
#include "./X_Command.hpp"
#include "./X_OC.hpp"
#include "./X_IO.hpp"
#include "./X_Chrono.hpp"
#include "./X_Fishhook.h"
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
		{ 'l', "lua",   "lua_file", true },
		{ 'p', "plist", "plist_file", true },
		{ 's', "sh",    "shell", true}
	}};

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
		cout << CS(Container) << endl;
		return 0;
	}

	auto OptShell = Cmd["shell"];
	if (OptShell()) {
		auto ShellCommand = *OptShell;
		//return system(ShellCommand.c_str());
		return 0;
	}
}
