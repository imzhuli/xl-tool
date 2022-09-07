#include "./Lua_All.hpp"
#include "../X_OC.hpp"
#include <ifaddrs.h>
#include <arpa/inet.h>

std::string GetFMVersion()
{
    return "0.1.0";
}

std::string GetDeviceIdfv()
{
    NSUUID * Idfv = [[UIDevice currentDevice] identifierForVendor];
    return ToString(Idfv);
}

std::string GetIpAddress()
{
    NSString *address = @"";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                char AddressBuffer[64] = {};
                inet_ntop(AF_INET, &((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr, AddressBuffer, sizeof(AddressBuffer));
                LuaLogger.D("GetLocalIp: Name=%s, Address=%s", temp_addr->ifa_name, AddressBuffer);

                if (0 == strncmp(temp_addr->ifa_name, "en", 2)) {
                    address = [NSString stringWithUTF8String:AddressBuffer];
                    break;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return ToString(address);
}

int Lua_GetIpAddress(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    return W.Return(GetIpAddress());
}