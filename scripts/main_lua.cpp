#include "./Lua_All.hpp"
#include "./main_lua.hpp"
#include <string>
#include <vector>
#include <atomic>
#include <ftw.h>

static std::atomic_bool Run = false;
static std::vector<std::thread> Threads;
static xTaskListManager TaskListManager;
std::atomic_bool PublicStopFlag = false;

static int Lua_Exit(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    PublicStopFlag = true;
	return W.Return();
}

static int Lua_AppendLocalScriptTask(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    lua_getglobal(LP, "LuaTaskList");
    auto [Script, UserContextPtr]  = W.Pop<std::string, void *>();
    auto TaskListPtr = (xTaskList*)UserContextPtr;

    auto TaskPtr = xTask::New();
    TaskPtr->TaskScript=std::move(Script);
    TaskListPtr->AddTail(*TaskPtr);
    return 0;
}

static void LuaTaskThread()
{
    xLuaState LuaState;
    xTaskList TaskList;

    LuaState.SetGlobal("LuaExit", &Lua_Exit);
    LuaState.SetGlobal("LuaLog", &Lua_Log);
    LuaState.SetGlobal("LuaMakeFile", &Lua_MakeFile);
    LuaState.SetGlobal("LuaHttpGet", &Lua_HttpGet);
    LuaState.SetGlobal("LuaHttpPostForm", &Lua_HttpPostForm);
    LuaState.SetGlobal("LuaHttpPostJson", &Lua_HttpPostJson);
    LuaState.SetGlobal("LuaHttpPostText", &Lua_HttpPostRawText);
    LuaState.SetGlobal("LuaHttpDownloadFile", &Lua_HttpDownloadFile);
    LuaState.SetGlobal("LuaRemove", &Lua_Remove);
    LuaState.SetGlobal("LuaIpaInstall", &Lua_IpaInstall);
    LuaState.SetGlobal("LuaIpaLaunchBySchemeUrl", &Lua_IpaLaunchBySchemeUrl);
    LuaState.SetGlobal("LuaUuid", Lua_Uuid);
    LuaState.SetGlobal("LuaMd5File", &Lua_Md5File);
    LuaState.SetGlobal("LuaSleepMS", &Lua_SleepMS);
    LuaState.SetGlobal("LuaIpaLaunchByBundleId", &Lua_IpaLaunchByBundleId);
    LuaState.SetGlobal("LuaIpaLaunchByBundleId", &Lua_IpaLaunchByBundleId);
    LuaState.SetGlobal("LuaGetIpAddress", &Lua_GetIpAddress);

    LuaState.SetGlobal("LuaGetIpaDataDirectories", &Lua_GetIpaDataDirectories);

    LuaState.SetGlobal("LuaDeviceIdfv", GetDeviceIdfv());
    LuaState.SetGlobal("LuaFMVersion", GetFMVersion());

    LuaState.SetGlobal("LuaTaskList", &TaskList);
    LuaState.SetGlobal("LuaAppendScriptTask", &Lua_AppendLocalScriptTask);

    LuaState.Execute(GlobalLua);
    LuaState.Execute(JsonLua);

    while(Run) {
        TaskListManager.GetTaskListFor(TaskList, 10ms);
        while(auto TaskPtr = TaskList.Head()) {
            LuaLogger.I("GotTask: script_length=%zi", TaskPtr->TaskScript.length());
            auto [Result, ErrorString] = LuaState.Execute(TaskPtr->TaskScript.c_str());
            if (Result) {
                auto ResultLength = LuaState.GetTop();
                LuaLogger.I("TaskExcutionFinished, ResultLength=%i", (int)ResultLength);
                if (ResultLength == 0) {
                    LuaLogger.I("LuaScriptFinished without return value");
                }
                else if (ResultLength == 1) {
                    auto [Ok] = LuaState.Get<bool>();
                    LuaLogger.I("LuaScriptResult: %s", YN(Ok));
                }
                else if (ResultLength == 2) {
                    auto [Ok, ResultString] = LuaState.Get<bool, std::string>();
                    LuaLogger.I("LuaScriptResult: %s, message=%s", YN(Ok), ResultString.c_str());
                    TaskPtr->ResultString = std::move(ResultString);
                }
                else {
                    LuaLogger.I("LuaScriptFinished without agreed format");
                }
            }
            else {
                LuaLogger.E("LuaScriptError: %s", ErrorString.c_str());
            }
            LuaState.SetTop(0);
            xTask::DoCallback(TaskPtr, Result);
        }
    }
};

static void PostLuaTask(xTask* TaskPtr)
{
    TaskListManager.PutTask(TaskPtr);
}

void main_lua_init(size_t TaskThreadCount, const std::string & InitTask)
{
    assert(!Run && Threads.empty());
    LuaLogger.Init(nullptr, true);
    if (!TaskThreadCount) {
        TaskThreadCount = 1;
    }
    PublicStopFlag = false;
    Run = true;
    for (size_t i = 0 ; i < TaskThreadCount; ++i) {
        Threads.push_back(std::thread(LuaTaskThread));
    }

    if (InitTask.size()) {
        PostLuaScript(InitTask);
    }
    LuaLogger.I("lua inited");
}

void main_lua_uninit(void)
{
    Run = false;
    PublicStopFlag = false;
    for (auto & Thread : Threads) {
        Thread.join();
    }
    LuaLogger.I("lua uninited");
    LuaLogger.Clean();
}

void PostLuaScript(const std::string & LuaScript)
{
    auto RegisterTask = xTask::New();
    RegisterTask->TaskScript = LuaScript;
    PostLuaTask(RegisterTask);
}