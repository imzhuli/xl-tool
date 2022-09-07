#pragma once
#include "../X_Lua.hpp"
#include <string>

extern std::string HttpGet(const char * URLStr);
extern std::string HttpPostForm(const char * URLStr, const std::string &RequestData);
extern std::string HttpPostJson(const char * URLStr, const std::string &Json);
extern bool HttpDownloadFile(const char * UrlStr, const char * Filename);

extern int Lua_HttpGet(lua_State * LP);
extern int Lua_HttpPostForm(lua_State * LP);
extern int Lua_HttpPostJson(lua_State * LP);
extern int Lua_HttpDownloadFile(lua_State * LP);
