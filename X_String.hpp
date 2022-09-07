#pragma once
#include "./X.hpp"
#include <vector>
#include <string>
#include <string_view>
#include <cstring>

using namespace std::literals::string_view_literals;

std::vector<std::string> Split(const std::string_view & s, const char * d, size_t len);
static inline std::vector<std::string> Split(const std::string_view & s, const char * d) { return Split(s, d, strlen(d)); }

std::string Trim(const std::string_view & s);
void Reverse(void * str, size_t len);
void CStrNCpy(char * dst, size_t n, const char * src);
template<size_t N>
void CStrNCpy(char (&dsrArr)[N], const char *src) {
    CStrNCpy((char *)dsrArr, N, src);
}

std::string HexShowLower(const void * buffer, size_t len, bool header = false);
std::string HexShow(const void * buffer, size_t len, bool header = false);

void HexToStr(void * dst, const void * str, size_t len);
std::string HexToStr(const void * str, size_t len);

void StrToHexLower(void * dst, const void * str, size_t len);
std::string StrToHexLower(const void * str, size_t len);
std::string StrToHexLower(const char * str);
static inline std::string StrToHexLower(const std::string_view & sv) {
    return StrToHexLower(sv.data(), sv.length());
}

void StrToHex(void * dst, const void * str, size_t len);
std::string StrToHex(const void * str, size_t len);
std::string StrToHex(const char * str);
static inline std::string StrToHex(const std::string_view & sv) {
    return StrToHex(sv.data(), sv.length());
}

std::u32string ToUtf32(const std::string_view & U8String);
std::string ToUtf8(const std::u32string_view & U32String);
xOptional<std::string> FileToStr(const char * filename);
static inline xOptional<std::string> FileToStr(const std::string & filename)  {
    return FileToStr(filename.c_str());
}
