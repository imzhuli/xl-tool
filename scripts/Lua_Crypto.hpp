#pragma once

#include "../X_Lua.hpp"
#include <string>

extern std::string Md5HexFile(const char * filename);
extern std::string Md5HexString(const void * DataPtr, size_t Size);

extern int Lua_Md5File(lua_State * LP);
