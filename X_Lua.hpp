#pragma once
#include "./X.hpp"
#include <tuple>
#include <string>
#include <vector>

extern "C" {
#include "./3rd/lua/lua.h"
#include "./3rd/lua/lualib.h"
#include "./3rd/lua/lauxlib.h"
}

// debug:
// #include "./X_Logger.hpp"
// extern xSimpleLogger LuaLogger;

class xLuaStateWrapper
{
public:
    xLuaStateWrapper() = default;
    xLuaStateWrapper(lua_State * LuaStatePtr) : _LuaStatePtr(LuaStatePtr) {}
    ~xLuaStateWrapper() = default;

    operator lua_State * () const { return _LuaStatePtr; }

    void GC() const {
        lua_gc(_LuaStatePtr, LUA_GCCOLLECT);
    }

    bool LoadString(const char * CodeStr) {
        return LUA_OK == luaL_loadstring(_LuaStatePtr, CodeStr);
    }
    bool LoadString(const std::string & CodeStr) {
        return LUA_OK == luaL_loadstring(_LuaStatePtr, CodeStr.c_str());
    }

    template<typename tArg>
    std::enable_if_t<std::is_same_v<tArg, bool>, tArg> GetAt(int Index) const { return (tArg)lua_toboolean(_LuaStatePtr, Index); }
    template<typename tArg>
    std::enable_if_t<std::is_integral_v<tArg> && !std::is_same_v<tArg, bool>, tArg> GetAt(int Index) const { return (tArg)lua_tointeger(_LuaStatePtr, Index); }
    template<typename tArg>
    std::enable_if_t<std::is_floating_point_v<tArg>, tArg> GetAt(int Index) const { return (tArg)lua_tonumber(_LuaStatePtr, Index); }
    template<typename tArg>
    std::enable_if_t<std::is_same_v<tArg, void *>, tArg> GetAt(int Index) const { return lua_touserdata(_LuaStatePtr, Index); }
    template<typename tArg>
    std::enable_if_t<std::is_same_v<tArg, const void *>, tArg> GetAt(int Index) const { return lua_touserdata(_LuaStatePtr, Index); }
    template<typename tArg>
    std::enable_if_t<std::is_same_v<tArg, char *>, tArg> GetAt(int Index) const { static_assert("Lua.GetAt<char*>() is forbidden"); return nullptr; }
    template<typename tArg>
    std::enable_if_t<std::is_same_v<tArg, const char *>, tArg> GetAt(int Index) const { return lua_tostring(_LuaStatePtr, Index); }
    template<typename tArg>
    std::enable_if_t<std::is_same_v<tArg, std::string>, tArg> GetAt(int Index) const { auto CStringPtr = lua_tostring(_LuaStatePtr, Index); return CStringPtr ? CStringPtr : ""; }

    int  GetTop() const { return lua_gettop(_LuaStatePtr); }
    void SetTop(int Index) const { lua_settop(_LuaStatePtr, Index); }
    void PopN(int Number) const { lua_pop(_LuaStatePtr, Number); }

    void Push() const {}
    void Push(char * StrValue) const { lua_pushstring(_LuaStatePtr, StrValue); }
    void Push(const char * StrValue) const { lua_pushstring(_LuaStatePtr, StrValue); }
    void Push(const std::string& StrValue) const { lua_pushstring(_LuaStatePtr, StrValue.c_str()); }
    void Push(int (*Func)(lua_State*)) const { lua_pushcfunction(_LuaStatePtr, Func); }
    template<typename tArg>
    std::enable_if_t<std::is_pointer_v<tArg>> Push(tArg Value) const { lua_pushlightuserdata(_LuaStatePtr, (void*)Value); }
    template<typename tArg>
    std::enable_if_t<std::is_same_v<tArg, bool>> Push(tArg Value) const { lua_pushboolean(_LuaStatePtr, Value); }
    template<typename tArg>
    std::enable_if_t<std::is_integral_v<tArg> && !std::is_pointer_v<tArg> && !std::is_same_v<tArg, bool>> Push(tArg Value) const { lua_pushinteger(_LuaStatePtr, (lua_Integer)Value); }
    template<typename tArg>
    std::enable_if_t<std::is_floating_point_v<tArg>> Push(tArg Number) const { lua_pushnumber(_LuaStatePtr, Number); }
    template<typename...Args>
    void PushFS(const char * FmtStr, Args&&...args) const { lua_pushfstring(_LuaStatePtr, FmtStr, std::forward<Args>(args)...); }
    template<typename tK, typename tV>
    ZEC_INLINE void Push(const std::pair<tK, tV> & KVPair) const {
        Push(KVPair.first);
        Push(KVPair.second);
    }
    template<typename T>
    ZEC_INLINE void Push(const xIteratorRange<T> & Range) const {
        lua_newtable(_LuaStatePtr);
        size_t Index = 0;
        for (auto & Item : Range) {
            Push(++Index);
            Push(Item);
            lua_settable(_LuaStatePtr, -3);
        }
    }

    template<typename tFirstArg, typename...tOtherArgs>
    std::enable_if_t<static_cast<bool>(sizeof...(tOtherArgs))> Push(tFirstArg&& FirstArg, tOtherArgs&&...args) const {
        Push(std::forward<tFirstArg>(FirstArg));
        Push(std::forward<tOtherArgs>(args)...);
    }

    template<typename...Args>
    [[nodiscard]]
    int Return(Args&&...args) const {
        Push(std::forward<Args>(args)...);
        return (int)sizeof...(args);
    }

    template<typename...Args>
    void SetGlobal(const char * name, Args&&...args) const {
        Push(std::forward<Args>(args)...);
        lua_setglobal(_LuaStatePtr, name);
    }

    bool PopBool() const {
        auto Top = lua_gettop(_LuaStatePtr);
        assert (Top);
        auto Ret = lua_toboolean(_LuaStatePtr, Top);
        lua_pop(_LuaStatePtr, 1);
        return Ret;
    }

    lua_Integer PopInt() const {
        auto Top = lua_gettop(_LuaStatePtr);
        assert (Top);
        auto Ret = lua_tointeger(_LuaStatePtr, Top);
        lua_pop(_LuaStatePtr, 1);
        return Ret;
    }

    lua_Number PopNumber() const {
        auto Top = lua_gettop(_LuaStatePtr);
        assert (Top);
        auto Ret = lua_tonumber(_LuaStatePtr, Top);
        lua_pop(_LuaStatePtr, 1);
        return Ret;
    }

    std::string PopString() const {
        auto Top = lua_gettop(_LuaStatePtr);
        assert (Top);
        std::string Ret = lua_tostring(_LuaStatePtr, Top);
        lua_pop(_LuaStatePtr, 1);
        return Ret;
    }

    template<typename...tArgs>
    std::enable_if_t<(sizeof...(tArgs) >= 1),std::tuple<tArgs...>> Get() const {
        auto Top = lua_gettop(_LuaStatePtr); assert (Top);
        std::tuple<tArgs...> Result;
        _FillTuple<0, true>(Result, Top + 1 - sizeof...(tArgs));
        return Result;
    }

    template<typename...tArgs>
    std::enable_if_t<(sizeof...(tArgs) == 0)> Pop() const {}

    template<typename...tArgs>
    std::enable_if_t<(sizeof...(tArgs) >= 1),std::tuple<tArgs...>> Pop() const {
        auto Top = lua_gettop(_LuaStatePtr); assert (Top);
        std::tuple<tArgs...> Result;
        _FillTuple<0>(Result, Top + 1 - sizeof...(tArgs));
        lua_pop(_LuaStatePtr, (int)(sizeof...(tArgs)));
        return Result;
    }

    void Error(const char * Reason) const { lua_pushstring(_LuaStatePtr, Reason); lua_error(_LuaStatePtr); }
    std::tuple<bool, std::string> Execute(const char * CodeStr) const {
        if (LUA_OK == luaL_dostring(_LuaStatePtr, CodeStr)) {
            return std::make_tuple(true, std::string{});
        }
        return std::make_tuple(false, PopString());
    }
    std::tuple<bool, std::string> ExecuteFile(const char * Filename) const {
                if (LUA_OK == luaL_dofile(_LuaStatePtr, Filename)) {
            return std::make_tuple(true, std::string{});
        }
        return std::make_tuple(false, PopString());
    }

    template<size_t ResultNumber = 0, typename...tArgs>
    void CallN(const char * name, tArgs&&...args) const {
        lua_getglobal(_LuaStatePtr, name);
        Push(std::forward<tArgs>(args)...);
        lua_call(_LuaStatePtr, sizeof...(args), ResultNumber);
    }

    template<typename...tRetVars, typename...tArgs>
    auto Call(const char * name, tArgs&&...args) const {
        CallN<sizeof...(tRetVars)>(name, std::forward<tArgs>(args)...);
        return Pop<tRetVars...>();
    }

protected:
    lua_State * _LuaStatePtr = nullptr;

private:
    template<size_t MemberIndex,  bool AllowCString = false, typename tTuple>
    void _FillTuple(tTuple & Tuple, int StackOffset) const {
        static_assert(AllowCString || !std::is_same_v<std::remove_reference_t<decltype(std::get<MemberIndex>(Tuple))>, const char *>);
        std::get<MemberIndex>(Tuple) = GetAt<std::remove_reference_t<decltype(std::get<MemberIndex>(Tuple))>>(StackOffset);
        if constexpr(MemberIndex < std::tuple_size<tTuple>() - 1) {
            _FillTuple<MemberIndex + 1, AllowCString>(Tuple, StackOffset + 1);
        }
    }
};

class xLuaState
: public xLuaStateWrapper
, xNonCopyable
{
public:
    xLuaState();
    ~xLuaState();
};
