#include "./X.hpp"
#include "./X_Command.hpp"
#include "./X_IO.hpp"
#include "./X_Chrono.hpp"
#include "./X_Fishhook.h"
#include "./scripts/main_lua.hpp"
#include <thread>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <dlfcn.h>

using namespace std;

static int (*Orig_system)(const char * name);
static int Override_system(const char * name) {
	return Orig_system(name);
}

static struct rebinding Rebindins[] = {
	{
		"system", (void*)Override_system, (void**)&Orig_system
	}
};

static void DoRebindings() {
	rebind_symbols(Rebindins, Length(Rebindins));
	if (!Orig_system) {
		cerr << "Failed to bind Orig_system" << endl;
	}
}

int main(int argc, char *argv[], char *envp[]) {
	DoRebindings();
	xCommandLine Cmd = { argc, argv, {
		{ 'f', "lua_file", "lua_file", true },
		{ 's', "sh", "shell", true}
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

	auto OptShell = Cmd["shell"];
	if (OptShell()) {
		auto ShellCommand = *OptShell;
		//return system(ShellCommand.c_str());
		return 0;
	}
}
