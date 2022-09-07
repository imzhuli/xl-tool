#pragma once
#include "../X_Lua.hpp"
#include <string>

extern bool AppLaunch(const std::string & BundleId);
extern bool AppLaunchUrl(const std::string & Url);
extern std::string IpaInstall(const std::string & IpaPath); // return value: bundle_id
extern std::string GenerateUuid();

extern int Lua_SleepMS(lua_State * LP);
extern int Lua_Remove(lua_State * LP);
extern int Lua_IpaInstall(lua_State *LP);
extern int Lua_IpaLaunchByBundleId(lua_State * LP);
extern int Lua_IpaLaunchBySchemeUrl(lua_State * LP);
extern int Lua_Uuid(lua_State * LP);
extern int Lua_MakeFile(lua_State * LP);
