#pragma once
#include "../X_Lua.hpp"
#include <string>

extern std::string GetFMVersion();
extern std::string GetDeviceIdfv();
extern std::string GetIpAddress();

extern int Lua_GetIpAddress(lua_State * LP);
