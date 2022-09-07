#include "./Lua_All.hpp"

xSimpleLogger LuaLogger;

int Lua_Log(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [LogString] = W.Get<const char*>();
    LuaLogger.I("[LuaScript] %s", LogString);
    W.PopN(1);
	return 0;
}
