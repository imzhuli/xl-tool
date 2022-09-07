#include "./X_IO.hpp"
#include "X_OC.hpp"
#include <fstream>

std::string ReadFile(const char * filename)
{
    std::ifstream InFile(filename);
    if (!InFile) {
        return {};
    }

    char Buffer[1024];
    std::string Output;
    while(!InFile.eof()) {
        InFile.read(Buffer, sizeof(Buffer));
        size_t ReadSize = InFile.gcount();
        Output.append(Buffer, ReadSize);
    }

    return Output;
}
