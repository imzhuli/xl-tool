#pragma once
#include "./Lua_Task.hpp"
#include <atomic>
#include <string>

extern const char * GlobalLua;
extern const char * JsonLua;
extern std::atomic_bool PublicStopFlag;

extern void main_lua_init(size_t TaskThreadCount = 1, const std::string & InitTask = {});
extern void main_lua_uninit(void);
extern void PostLuaScript(const std::string & LuaScript);
