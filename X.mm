#include "./X.hpp"
#include <cstdio>

bool X_ENABLE_HOOK = false;

static const char * LogFileName = "/var/log/x.log";
static FILE * LogFilePtr = NULL;
void X_Log(const char * Fmt, ...)
{
    if (!LogFilePtr) {
        return;
    }
    va_list Args;
    va_start(Args, Fmt);
	vfprintf(LogFilePtr, Fmt, Args);
    fputc('\n', LogFilePtr);
    fflush(LogFilePtr);
	va_end(Args);
}

static auto LogFileGuard = xScopeGuard {
    []{
        LogFilePtr = fopen(LogFileName, "w+");
    },
    []{
        if (LogFilePtr) {
            fclose(LogFilePtr);
        }
    }
};
