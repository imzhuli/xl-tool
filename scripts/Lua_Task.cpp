#include "./Lua_Task.hpp"

void xTaskListManager::PutTask(xTask * TaskPtr) {
    TaskEvent.Notify([&]{
        TaskList.GrabTail(*TaskPtr);
    });
}

void xTaskListManager::GetTaskList(xTaskList & TagetList)
{
    TaskEvent.Wait([&]{
        TagetList.GrabListTail(TaskList);
    });
}

void xTaskListManager::GetTaskListFor(xTaskList & TargetList, xSteadyDuration Duration)
{
    TaskEvent.WaitFor(Duration, [&]{
        TargetList.GrabListTail(TaskList);
    });
}

void xTaskListManager::TryGetTaskList(xTaskList & TargetList)
 {
    TaskEvent.SyncCall([&]{
        TargetList.GrabListTail(TaskList);
    });
}
