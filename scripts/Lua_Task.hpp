#pragma once
#include "../X.hpp"
#include "../X_List.hpp"
#include "../X_Chrono.hpp"
#include "../X_Thread.hpp"
#include "../X_Logger.hpp"
#include <string>

struct xTask;
using xTaskDoneCallback = void(xTask* TaskPtr, bool Done);

struct xTask final
: xListNode
, xNonCopyable
{
    std::string TaskScript;
    std::string ResultString;
    xVariable   UserContext{};

    static xTask * New(xTaskDoneCallback*Callback = nullptr) {
        auto TaskPtr = new xTask();
        if (Callback) {
            TaskPtr->_CallbackPtr = Callback;
        } else {
            TaskPtr->_CallbackPtr = DeleteOnCallback;
        }
        return TaskPtr;
    }
    static void Delete(xTask * TaskPtr) { delete TaskPtr; }
    static void DoCallback(xTask * TaskPtr, bool Done) { TaskPtr->_CallbackPtr(TaskPtr, Done); }

private:
    xTask() = default;
    xTaskDoneCallback * _CallbackPtr = nullptr;
    static void DeleteOnCallback(xTask * TaskPtr, bool Done) { Delete(TaskPtr); }
};

using xTaskList = xList<xTask>;

struct xTaskListManager final
{
public:
    void PutTask(xTask * TaskPtr);
    void GetTaskList(xTaskList & TargetList);
    void GetTaskListFor(xTaskList & TargetList, xSteadyDuration Duration);
    void TryGetTaskList(xTaskList & TagetList);

private:
    xAutoResetEvent    TaskEvent;
    xTaskList          TaskList;
} ;
