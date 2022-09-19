#include "./X_OC.hpp"
#include <objc/objc-runtime.h>
#include <iostream>
using namespace std;

NSString *  NS(const std::string & String)
{
    return [NSString stringWithUTF8String:String.c_str()];
}

std::string XS(id OcObjectId)
{
    if (!OcObjectId) {
        return "(nil)";
    }
    return [[OcObjectId description] cStringUsingEncoding:NSUTF8StringEncoding];
}

id PlistToContainer(const std::string & PlistContents)
{
    NSError * Error = nil;
    NSData * data = [NSData dataWithBytes:PlistContents.data() length:PlistContents.length()];
    return [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&Error];
}
