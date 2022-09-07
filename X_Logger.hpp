#pragma once
#include "./X.hpp"
#include "./X_Thread.hpp"
#include <filesystem>
#include <cstring>
#include <cstdio>
#include <mutex>
#include <atomic>
#include <cinttypes>

enum struct eLogLevel : int_fast32_t
{	// !!! Note: implementation may use the value as index of output string,
    // so, ALWAYS increase values by ONE,
    Verbose = 0,
    Debug   = 1,
    Info    = 2,
    Error   = 3,
    Quiet   = 1024,
};

class xLogger : xAbstract
{
public:
    xLogger();
    ~xLogger();

    virtual void UpdateConfig(const char * aConfigData, size_t cConfigDataSize);
    virtual void SetLogLevel(eLogLevel ll) = 0;
    virtual void Log(eLogLevel ll, const char * fmt, ...) = 0;
    virtual void Truncate() {}

    // helper functions
    void UpdateConfig(const char * aConfigData) { UpdateConfig(aConfigData, strlen(aConfigData)); }

    template<typename ... Args>
    void V(const char * fmt, Args&& ... args) {
        Log(eLogLevel::Verbose, fmt, std::forward<Args>(args)...);
    }

#ifndef NDEBUG
    template<typename ... Args>
    void D(const char * fmt, Args&& ... args) {
        Log(eLogLevel::Debug, fmt, std::forward<Args>(args)...);
    }
#else
    template<typename ... Args>
    void D(const char * fmt, Args&& ... args) {
        Pass();
    }
#endif

    template<typename ... Args>
    void I(const char * fmt, Args&& ... args) {
        Log(eLogLevel::Info, fmt, std::forward<Args>(args)...);
    }

    template<typename ... Args>
    void E(const char * fmt, Args&& ... args) {
        Log(eLogLevel::Error, fmt, std::forward<Args>(args)...);
    }
};

class xNonLogger final
: public xLogger
{
    void SetLogLevel(eLogLevel ll) override {}
    void Log(eLogLevel ll, const char * fmt, ...) override {};
};

class xSimpleLogger final
: public xLogger
{
public:
    xSimpleLogger();
    ~xSimpleLogger();

    bool Init(const char * PathPtr = nullptr, bool AutoStdout = true);
    void Clean();
    bool IsStdout() const { return _LogFile == stdout; }

    void SetLogLevel(eLogLevel ll) override { _LogLevel = ll; }
    void Log(eLogLevel ll, const char * fmt, ...) override;
    void Truncate() override;

    FILE * Lock() {
        _SyncMutex.lock();
        if (!_LogFile) {
            _SyncMutex.unlock();
        }
        return _LogFile;
    }
    void Unlock(FILE * && ExpiringFilePtr) {
        assert(ExpiringFilePtr == _LogFile);
        _SyncMutex.unlock();
    }

private:
    std::filesystem::path        _LogFilename;
    std::mutex                   _SyncMutex;
    std::atomic<eLogLevel>       _LogLevel { eLogLevel::Debug };
    FILE *                       _LogFile = nullptr;
};

extern xNonLogger * const NonLoggerPtr;
