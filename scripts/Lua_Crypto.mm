#include "./Lua_Crypto.hpp"
#include "../X_String.hpp"
#include "../X_OC.hpp"
#import <CommonCrypto/CommonDigest.h>

std::string Md5HexFile(const char * filename)
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:NS(filename)];
	if( handle== nil ) return {}; // 如果文件不存在

	CC_MD5_CTX md5;
	CC_MD5_Init(&md5);
	while(true) {
		NSData* fileData = [handle readDataOfLength:256];
        if (![fileData length]) {
            break;
        }
		CC_MD5_Update(&md5, [fileData bytes], [fileData length]);
    }
	unsigned char Result[CC_MD5_DIGEST_LENGTH];
	CC_MD5_Final(Result, &md5);
    return StrToHex(Result, 16);
}

std::string Md5HexString(const void * DataPtr, size_t Size)
{
    unsigned char Result[16];
    CC_MD5(DataPtr, (CC_LONG)Size, Result);
    return StrToHex(Result, 16);
}

int Lua_Md5File(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Filename] = W.Get<const char *>();
    std::string Hex = Md5HexFile(Filename);
    W.SetTop(0);
	return W.Return(Hex);
}
