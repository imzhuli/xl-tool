#include "./X.hpp"
#include "./X_Command.hpp"
#include "./X_IO.hpp"
#include "./X_Chrono.hpp"
#include "./scripts/main_lua.hpp"
#include <thread>
#include <cstdio>

int main(int argc, char *argv[], char *envp[]) {
	xCommandLine Cmd = { argc, argv, {
		{ 'f', "lua_file", "lua_file", true }
	}};

	auto OptLuaFile = Cmd["lua_file"];
	if (!OptLuaFile()) {
		cerr << "missing option lua_file" << endl;
		return -1;
	}
	auto LuaScript = ReadFile(OptLuaFile->c_str());

	main_lua_init(1, LuaScript);
	while(!PublicStopFlag) {
		std::this_thread::sleep_for(50ms);
	}
	main_lua_uninit();
}
