#include "./X_OC.hpp"

NSString *  NS(const std::string & String)
{
    return [NSString stringWithUTF8String:String.c_str()];
}

std::string ToString(id OcObjectId)
{
    if (!OcObjectId) {
        return "(nil)";
    }
    return [[OcObjectId description] cStringUsingEncoding:NSUTF8StringEncoding];
}
