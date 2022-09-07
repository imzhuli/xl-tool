#pragma once
#include "./X.hpp"
#include <chrono>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>

template<typename tMutex, typename tFuncObj, typename ... tArgs>
auto SyncCall(tMutex && Mutex, tFuncObj && Func, tArgs && ... Args)
{
    auto Guard = std::lock_guard(std::forward<tMutex>(Mutex));
    return std::forward<tFuncObj>(Func)(std::forward<tArgs>(Args)...);
}

class xSpinlock final
{
public:
    void Lock() const noexcept {
        for (;;) {
            // Optimistically assume the lock is free on the first try
            if (!_LockVariable.exchange(true, std::memory_order_acquire)) {
                return;
            }
            // Wait for lock to be released without generating cache misses
            while (_LockVariable.load(std::memory_order_relaxed)) {
                // Issue X86 PAUSE or ARM YIELD instruction to reduce contention between
                // hyper-threads
                // gcc/clang: __builtin_ia32_pause();
                // msvc: _mm_pause();
            }
        }
    }

    bool TryLock() const noexcept {
        // First do a relaxed load to check if lock is free in order to prevent
        // unnecessary cache misses if someone does while(!try_lock())
        return !_LockVariable.load(std::memory_order_relaxed) &&
            !_LockVariable.exchange(true, std::memory_order_acquire);
    }

    void Unlock() const noexcept {
        _LockVariable.store(false, std::memory_order_release);
    }
private:
    mutable std::atomic<bool> _LockVariable = {0};
};

class xSpinlockGuard final
: xNonCopyable
{
public:
    [[nodiscard]] xSpinlockGuard(const xSpinlock & Spinlock)
    : _Spinlock(&Spinlock) {
        _Spinlock->Lock();
    }
    ~xSpinlockGuard() {
        _Spinlock->Unlock();
    }
private:
    const xSpinlock * _Spinlock;
};

class xThreadSynchronizer final
{
private:
    struct Context {
        int_fast32_t               xWaitingCount = 0;
        std::condition_variable    xCondtion;
    };

    std::mutex                 _Mutex;
    ssize32_t                  _TotalSize        = 0;
    uint_fast8_t               _ActiveContext    = 0;
    uint_fast8_t               _OtherContext     = 1;
    Context                    _Coutnexts[2];

public:
    void Aquire();
    void Release();
    void Sync();
};

namespace __detail__
{
    template<bool AutoReset = false>
    struct xEvent
    : xNonCopyable
    {
    private:
        std::mutex _Mutex;
        std::condition_variable _ConditionVariable;
        bool _Ready = false;

    public:
        void Reset() {
            auto Lock = std::unique_lock(_Mutex);
            _Ready = false;
        }

        template<typename tFuncObj>
        auto SyncCall(const tFuncObj & func) {
            auto Lock = std::unique_lock(_Mutex);
            return func();
        }

        template<typename tFuncPre, typename tFuncPost>
        ZEC_INLINE void Wait(const tFuncPre & funcPre, const tFuncPost & funcPost) {
            auto Lock = std::unique_lock(_Mutex);
            funcPre();
            _ConditionVariable.wait(Lock, [this](){return _Ready;});
            if constexpr (AutoReset) {
                _Ready = false;
            }
            // Notice : the Post function is called after auto reset,
            // just incase it throws exception;
            funcPost();
        }
        template<typename tFuncPost = xPass>
        void Wait(const tFuncPost & funcPost = {}) {
            auto Lock = std::unique_lock(_Mutex);
            _ConditionVariable.wait(Lock, [this](){return _Ready;});
            if constexpr (AutoReset) {
                _Ready = false;
            }
            // Notice : the Post function is called after auto reset,
            // just incase it throws exception;
            funcPost();
        }

        template<typename Rep, typename Period, typename tFuncPre, typename tFuncPost>
        ZEC_INLINE bool WaitFor(const std::chrono::duration<Rep, Period>& RelTime
                , const tFuncPre & funcPre,  const tFuncPost & funcPost) {
            auto Lock = std::unique_lock(_Mutex);
            funcPre();
            if (!_ConditionVariable.wait_for(Lock, RelTime, [this](){return _Ready;})) {
                return false;
            }
            if constexpr (AutoReset) {
                _Ready = false;
            }
            // Notice : the Post function is called after auto reset,
            // just incase it throws exception;
            funcPost();
            return true;
        }
        template<typename Rep, typename Period, typename tFuncPost>
        ZEC_INLINE bool WaitFor(const std::chrono::duration<Rep, Period>& RelTime, const tFuncPost & funcPost) {
            auto Lock = std::unique_lock(_Mutex);
            if (!_ConditionVariable.wait_for(Lock, RelTime, [this](){return _Ready;})) {
                return false;
            }
            if constexpr (AutoReset) {
                _Ready = false;
            }
            // Notice : the Post function is called after auto reset,
            // just incase it throws exception;
            funcPost();
            return true;
        }

        template<typename tFuncObj = xPass>
        std::enable_if_t<std::is_same_v<void, std::invoke_result_t<tFuncObj>>> Notify(const tFuncObj & PreNotifyFunc = {}) {
            auto Lock = std::unique_lock(_Mutex);
            PreNotifyFunc();
            _Ready = true; _ConditionVariable.notify_one();
        }

        template<typename tFuncObj = xPass>
        std::enable_if_t<std::is_same_v<void, std::invoke_result_t<tFuncObj>>> NotifyAll(const tFuncObj & PreNotifyFunc = {}) {
            auto Lock = std::unique_lock(_Mutex);
            PreNotifyFunc();
            _Ready = true; _ConditionVariable.notify_all();
        }
    };
}
using xEvent = __detail__::xEvent<false>;
using xAutoResetEvent = __detail__::xEvent<true>;

class xThreadChecker final
{
public:
    void Init()  { _ThreadId = std::this_thread::get_id(); }
    void Clean() { _ThreadId = {}; }
    void Check() { if (std::this_thread::get_id() != _ThreadId) { Error(); }};
private:
    std::thread::id _ThreadId;
};

#ifndef NDEBUG
	using xDebugThreadChecker = xThreadChecker;
#else
	class xDebugThreadChecker
	{
	public:
		void Init()  {}
		void Clean() {}
		void Check() {}
	};
#endif
