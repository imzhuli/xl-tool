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
    // const char * ContentString = [PlistContents cStringUsingEncoding:NSUTF8StringEncoding];
    // size_t ContentStringLength = strlen(ContentString);
    NSData * data = [NSData dataWithBytes:PlistContents.data() length:PlistContents.length()];

    NSError * Error = nil;
    return [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&Error];
}
