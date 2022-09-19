#pragma once
#include "./X.h"
#include <type_traits>
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cassert>
#include <iostream>
using std::cout;
using std::cerr;
using std::endl;

inline namespace x_numeric
{
    using byte  = ::std::byte;
    using ubyte = unsigned char;

    using size8_t      = ::std::uint8_t;
    using size16_t     = ::std::uint16_t;
    using size32_t     = ::std::uint32_t;
    using size64_t     = ::std::uint64_t;

    using ssize8_t     = ::std::int8_t;
    using ssize16_t    = ::std::int16_t;
    using ssize32_t    = ::std::int32_t;
    using ssize64_t    = ::std::int64_t;

    using offset8_t    = ::std::int8_t;
    using offset16_t   = ::std::int16_t;
    using offset32_t   = ::std::int32_t;
    using offset64_t   = ::std::int64_t;
    using offset_t     = ::std::ptrdiff_t;

    using size_t       = ::std::size_t;
    using ssize_t      = typename ::std::make_signed<size_t>::type;

} // namespace numeric

union xVariable
{
    ubyte                         B[8];

    void *                        Ptr;
    const void *                  CstPtr;
    const char *                  Str;

    ptrdiff_t                     Offset;
    size_t                        Size;

    int                           I;
    unsigned int                  U;
    int8_t                        I8;
    int16_t                       I16;
    int32_t                       I32;
    int64_t                       I64;
    uint8_t                       U8;
    uint16_t                      U16;
    uint32_t                      U32;
    uint64_t                      U64;

    struct { int32_t  x, y; }     VI32;
    struct { uint32_t x, y; }     VU32;
};

struct xPass final { inline void operator()() const {} };
struct xAbstract { protected: constexpr xAbstract() = default; virtual ~xAbstract() = default; xAbstract(xAbstract &&) = delete; };
struct xNonCopyable { protected: constexpr xNonCopyable() = default; ~xNonCopyable() = default; xNonCopyable(xNonCopyable &&) = delete; };
struct xNonCatchable final { private: constexpr xNonCatchable() = default; ~xNonCatchable() = default; };

static constexpr struct xNone final {} None;

static inline void Pass() {};
static inline void Error() { throw nullptr; }
static inline void Error(const char * message) { throw message; }
static inline void Fatal() { std::abort(); }
static inline void Fatal(const char *) { std::abort(); }
static inline void Todo() { Fatal(); }
static inline void Todo(const char * info) { Fatal(); }
static inline void Pure() { Fatal("placeholder of pure function called, which is not expected"); }
static inline constexpr const char * YN(bool y) { return y ? "yes" : "no"; }
static inline constexpr const char * TF(bool t) { return t ? "true" : "false"; }

template<typename T1, typename T2>
using xDiff = decltype(std::declval<T1>() - std::declval<T2>());
template<typename T1, typename T2> constexpr auto Diff(const T1& Value, const T2& ComparedToValue) { return Value - ComparedToValue; }
template<typename T1, typename T2> constexpr auto SignedDiff(const T1& Value, const T2& ComparedToValue) { return static_cast<std::make_signed_t<xDiff<T1, T2>>>(Value - ComparedToValue); }
template<typename T1, typename T2> constexpr auto UnsignedDiff(const T1& Value, const T2& ComparedToValue) { return static_cast<std::make_unsigned_t<xDiff<T1, T2>>>(Value - ComparedToValue); }

template<typename T>
class xRef final {
public:
    [[nodiscard]] constexpr explicit xRef(T & Ref) noexcept : _Ref(&Ref) {}
    [[nodiscard]] constexpr xRef(const xRef & RRef) noexcept = default;
    inline constexpr T& Get() const noexcept { return *_Ref; }
private:
    T * _Ref;
};
template<typename RefedT>
struct xRefCaster {
    static_assert(!std::is_reference_v<RefedT>);
    using Type = RefedT;
    static inline RefedT& Get(RefedT & R) { return R; }
    static inline const RefedT& Get(const RefedT & R) { return R; }
};
template<typename RefedT>
struct xRefCaster<xRef<RefedT>> {
    static_assert(!std::is_reference_v<RefedT>);
    using Type = RefedT;
    static inline RefedT& Get(const xRef<RefedT> & RR) { return RR.Get(); }
};

template<typename tFuncObj, typename ... Args>
struct xInstantRun final : xNonCopyable	{
    inline xInstantRun(tFuncObj && Func, Args&& ... args) { std::forward<tFuncObj>(Func)(std::forward<Args>(args)...); }
};
template<typename tEntry, typename tExit>
class xScopeGuard final : xNonCopyable {
private:
    tExit _ExitCallback;
    bool  _DismissExit = false;
public:
    [[nodiscard]] inline xScopeGuard(const tEntry& Entry, const tExit& Exit) : _ExitCallback(Exit) { Entry(); }
    [[nodiscard]] inline xScopeGuard(const tExit& Exit) : _ExitCallback(Exit) {}
    [[nodiscard]] inline xScopeGuard(xScopeGuard && Other) : _ExitCallback(Other._ExitCallback), _DismissExit(Steal(Other._DismissExit, true)) {}
    inline void Dismiss() { _DismissExit = true; }
    inline ~xScopeGuard() { if (_DismissExit) { return; } xRefCaster<tExit>::Get(_ExitCallback)(); }
};
template<typename tEntry, typename tExit>
xScopeGuard(const tEntry& Entry, const tExit& Exit) -> xScopeGuard<std::decay_t<tEntry>, std::decay_t<tExit>>;
template<typename tExit>
xScopeGuard(const tExit& Exit) -> xScopeGuard<xPass, std::decay_t<tExit>>;
template<typename tEntry, typename tExit>
xScopeGuard(xScopeGuard<tEntry, tExit> && Other) -> xScopeGuard<tEntry, tExit>;

template<typename IteratorType>
class xIteratorRange
{
    static_assert(!std::is_reference_v<IteratorType>);
    template<typename tIterator>
    struct xIsPairReference : std::false_type {};
    template<typename tK, typename tV>
    struct xIsPairReference<std::pair<tK, tV> &> : std::true_type {};
    template<typename tK, typename tV>
    struct xIsPairReference<const std::pair<tK, tV> &> : std::true_type {};

public:
    using iterator = IteratorType;
    static constexpr const bool IsPairIterator = xIsPairReference<decltype(*std::declval<IteratorType>())>::value;

    xIteratorRange() = delete;
    constexpr xIteratorRange(const IteratorType & Begin, const IteratorType & End): _Begin(Begin), _End(End) {}
    template<typename tContainer>
    constexpr xIteratorRange(tContainer & Container) : xIteratorRange(Container.begin(), Container.end()) {}
    template<typename tContainer>
    constexpr xIteratorRange(tContainer && Container) : xIteratorRange(Container.begin(), Container.end()) {}

    constexpr xIteratorRange(const xIteratorRange &) = default;
    constexpr xIteratorRange(xIteratorRange &&) = default;
    constexpr xIteratorRange & operator = (const xIteratorRange &) = default;
    constexpr xIteratorRange & operator = (xIteratorRange &&) = default;

    constexpr IteratorType begin() const { return _Begin; }
    constexpr IteratorType end()   const { return _End; }
    constexpr auto size() const { return _End - _Begin; }

private:
    IteratorType _Begin;
    IteratorType _End;
};
template<typename tWrapper>
xIteratorRange(const tWrapper&) -> xIteratorRange<typename tWrapper::iterator>;
template<typename tWrapper>
xIteratorRange(tWrapper&&) -> xIteratorRange<typename tWrapper::iterator>;

template<typename T>
class xOptional final {
    static_assert(!std::is_reference_v<T> && !std::is_const_v<T>);
    using Type = std::remove_cv_t<std::remove_reference_t<T>>;
    using xCaster = xRefCaster<T>;
    using xValueType = typename xCaster::Type;

public:
    inline xOptional() = default;
    inline ~xOptional() { if(_Valid) { Destroy(); } }
    inline xOptional(const xOptional & Other) {
        if (Other._Valid) {
            new ((void*)_Holder) Type(Other.GetReference());
            _Valid = true;
        }
    }
    inline xOptional(xOptional && Other) {
        if (Other._Valid) {
            new ((void*)_Holder) Type(std::move(Other.GetReference()));
            _Valid = true;
        }
    }
    template<typename U>
    inline xOptional(U&& Value) {
        new ((void*)_Holder) Type(std::forward<U>(Value));
        _Valid = true;
    }

    inline xOptional & operator = (const xOptional &Other) {
        if (_Valid) {
            if (Other._Valid) {
                GetReference() = Other.GetReference();
            } else {
                Destroy();
                _Valid = false;
            }
        } else {
            if (Other._Valid) {
                new ((void*)_Holder) Type(Other.GetReference());
                _Valid = true;
            }
        }
        return *this;
    }
    inline xOptional & operator = (xOptional && Other) {
        if (_Valid) {
            if (Other._Valid) {
                GetReference() = std::move(Other.GetReference());
            } else {
                Destroy();
                _Valid = false;
            }
        } else {
            if (Other._Valid) {
                new ((void*)_Holder) Type(std::move(Other.GetReference()));
                _Valid = true;
            }
        }
        return *this;
    }
    template<typename U>
    inline xOptional & operator = (U&& Value) {
        if (!_Valid) {
            new ((void*)_Holder) Type(std::forward<U>(Value));
            _Valid = true;
        } else {
            GetReference() = std::forward<U>(Value);
        }
        return *this;
    }

    inline void Reset() { Steal(_Valid) ? Destroy() : Pass(); }

    inline bool operator()() const { return _Valid; }

    inline auto & operator *() { assert(_Valid); return GetValueReference(); }
    inline auto & operator *() const { assert(_Valid); return GetValueReference(); }

    inline auto * operator->() { return _Valid ? &GetValueReference() : nullptr; }
    inline auto * operator->() const { return _Valid ? &GetValueReference() : nullptr; }

    inline const xValueType & Or(const xValueType & DefaultValue) const { return _Valid ? GetValueReference() : DefaultValue; }

private:
    inline Type & GetReference() { return reinterpret_cast<Type&>(_Holder); }
    inline const Type & GetReference() const { return reinterpret_cast<const Type&>(_Holder); }
    inline auto & GetValueReference() { return xCaster::Get(GetReference()); }
    inline auto & GetValueReference() const { return xCaster::Get(GetReference()); }
    inline void Destroy() { GetReference().~Type(); }

private:
    bool _Valid {};
    alignas(Type) ubyte _Holder[sizeof(Type)];
};

template<typename U>
xOptional(const U& Value) -> xOptional<U>;

template<typename U>
xOptional(U&& Value) ->  xOptional<U>;

template<size_t TargetSize, size_t Alignment = alignof(std::max_align_t)>
class xDummy final
: xNonCopyable
{
public:
    template<typename T>
    void CreateAs() {
        static_assert(Alignment >= alignof(T));
        static_assert(sizeof(_PlaceHolder) >= sizeof(T));
        new ((void*)_PlaceHolder) T;
    }

    template<typename T, typename ... tArgs>
    T& CreateValueAs(tArgs && ... Args) {
        static_assert(Alignment >= alignof(T));
        static_assert(sizeof(_PlaceHolder) >= sizeof(T));
        return *(new ((void*)_PlaceHolder) T(std::forward<tArgs>(Args)...));
    }

    template<typename T>
    void DestroyAs() {
        static_assert(Alignment >= alignof(T));
        static_assert(sizeof(_PlaceHolder) >= sizeof(T));
        reinterpret_cast<T*>(_PlaceHolder)->~T();
    }

    template<typename T>
    T & As() {
        static_assert(Alignment >= alignof(T));
        static_assert(sizeof(_PlaceHolder) >= sizeof(T));
        return reinterpret_cast<T&>(_PlaceHolder);
    }

    template<typename T>
    const T & As() const {
        static_assert(Alignment >= alignof(T));
        static_assert(sizeof(_PlaceHolder) >= sizeof(T));
        return reinterpret_cast<const T&>(_PlaceHolder);
    }

    static constexpr const size_t Size = TargetSize;

private:
    alignas(Alignment) ubyte _PlaceHolder[TargetSize];
};

    template<typename T>
    void
    Reset(T& ExpiringTarget) { ExpiringTarget = T{}; }

    template<typename T, typename TValue>
    void
    Reset(T& ExpiringTarget,  TValue && value) { ExpiringTarget = std::forward<TValue>(value); }

    template<typename T>
    void
    Renew(T& ExpiringTarget) {
        ExpiringTarget.~T();
        new ((void*)&ExpiringTarget) T;
    }

    template<typename T, typename...tArgs>
    void
    RenewValue(T& ExpiringTarget,  tArgs && ... Args) {
        ExpiringTarget.~T();
        new ((void*)&ExpiringTarget) T {std::forward<tArgs>(Args)...};
    }

template<typename T>
[[nodiscard]] T
Steal(T& ExpiringTarget) {
    T ret = std::move(ExpiringTarget);
    ExpiringTarget = T{};
    return ret;
}

template<typename T, typename TValue>
[[nodiscard]] T
Steal(T& ExpiringTarget,  TValue && value) {
    T ret = std::move(ExpiringTarget);
    ExpiringTarget = std::forward<TValue>(value);
    return ret;
}

template<typename T, size_t L>
[[nodiscard]] static inline constexpr size_t
Length(const T(&)[L]) { return L; }

template<typename T, size_t L>
[[nodiscard]] static inline constexpr size_t
SafeLength(const T(&)[L]) { return L ? L - 1 : L; }