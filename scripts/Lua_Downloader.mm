#include "./Lua_All.hpp"
#include "../X_OC.hpp"
#include "../X_Thread.hpp"

@interface DownloadDelegate: NSObject <NSURLSessionDataDelegate>
@property (nonatomic,strong) NSFileHandle * Handle ;
@property (nonatomic,strong) NSString * TargetFilename ;
@property (nonatomic) xEvent * EventHandle;
@property (nonatomic) BOOL Success;
-(void)Download:(NSURL *)Url ToFile:(NSString *)Filename WithTrigger:(xEvent *)Event;
@end

@implementation DownloadDelegate

-(void)Download:(NSURL *)Url ToFile:(NSString *)Filename  WithTrigger:(xEvent *)Event
{
    if (!Url || !Filename || _Handle || _EventHandle) {
        return;
    }
    self.EventHandle = Event;
    self.TargetFilename = Filename;
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSURLRequest *request = [NSURLRequest requestWithURL:Url];
    NSURLSessionConfiguration * configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
    [dataTask resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    //(1)创建空的文件
    [[NSFileManager defaultManager] createFileAtPath:_TargetFilename contents:nil attributes:nil];
    //(2)创建文件句柄指针指向文件
    self.Handle = [NSFileHandle fileHandleForWritingAtPath:_TargetFilename];
    //告诉系统应该接收数据
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.Handle writeData:data];
}

//3 下载完成或者失败的时候调用
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self.Handle closeFile];
    self.Success = (error == NULL) ? YES : NO;
    self.EventHandle->Notify();
}
@end

NSURLSession * DownloadSession()
{
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest = 5.0;
    sessionConfig.timeoutIntervalForResource = 5.0;
    return [NSURLSession sessionWithConfiguration:sessionConfig];
}

std::string HttpGet(const char * URLStr)
{
    NSURL *Url=[NSURL URLWithString:NS(URLStr)];
    NSURLRequest *Request=[[NSURLRequest alloc] initWithURL:Url];

    xEvent FinishEvent;
    __block xEvent * EventPtr = &FinishEvent;
    __block NSData * Data = NULL;

    NSURLSessionDataTask * Task = [DownloadSession() dataTaskWithRequest:Request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        Data = data;
        (EventPtr)->Notify();
    }];
    [Task resume];
    FinishEvent.Wait([]{});
    if(Data) {
        return { (const char *)Data.bytes, (size_t)Data.length };
    }
    return {};
}

std::string HttpPostForm(const char * URLStr, const std::string &RequestData)
{
    NSURL *Url=[NSURL URLWithString:NS(URLStr)];
    NSData * PostData = [NSData dataWithBytes:RequestData.data() length:RequestData.length()];
    NSMutableURLRequest *Request=[[NSMutableURLRequest alloc] initWithURL:Url];
    [Request setHTTPMethod:@"POST"];

    [Request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [Request setValue:[NSString stringWithFormat:@"%lu", [PostData length]] forHTTPHeaderField:@"Content-Length"];
    [Request setHTTPBody: PostData];

    xEvent FinishEvent;
    __block xEvent * EventPtr = &FinishEvent;
    __block NSData * Data = NULL;

    NSURLSessionDataTask * Task = [DownloadSession() dataTaskWithRequest:Request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        Data = data;
        (EventPtr)->Notify();
    }];
    [Task resume];
    FinishEvent.Wait([]{});
    if(Data) {
        return { (const char *)Data.bytes, (size_t)Data.length };
    }
    return {};
}

std::string HttpPostJson(const char * URLStr, const std::string &Json)
{
    NSURL *Url=[NSURL URLWithString:NS(URLStr)];
    NSData * PostData = [NSData dataWithBytes:Json.data() length:Json.length()];
    NSMutableURLRequest *Request=[[NSMutableURLRequest alloc] initWithURL:Url];
    [Request setHTTPMethod:@"POST"];
    [Request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [Request setValue:[NSString stringWithFormat:@"%lu", [PostData length]] forHTTPHeaderField:@"Content-Length"];
    [Request setHTTPBody: PostData];

    xEvent FinishEvent;
    __block xEvent * EventPtr = &FinishEvent;
    __block NSData * Data = NULL;

    NSURLSessionDataTask * Task = [DownloadSession() dataTaskWithRequest:Request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        Data = data;
        (EventPtr)->Notify();
    }];
    [Task resume];
    FinishEvent.Wait([]{});
    if(Data) {
        return { (const char *)Data.bytes, (size_t)Data.length };
    }
    return {};
}

bool HttpDownloadFile(const char * UrlStr, const char * Filename)
{
    xEvent FinishEvent;
    DownloadDelegate * Delegate = [[DownloadDelegate alloc] init];
    [Delegate Download:[NSURL URLWithString:NS(UrlStr)] ToFile:NS(Filename) WithTrigger:&FinishEvent];
    FinishEvent.Wait([]{});
    return [Delegate Success];
}

int Lua_HttpGet(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Url] = W.Pop<std::string>();
	return W.Return(HttpGet(Url.c_str()));
}

int Lua_HttpPostForm(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Url, Data] = W.Pop<std::string, std::string>();
	return W.Return(HttpPostForm(Url.c_str(), Data));
}

int Lua_HttpPostJson(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Url, Data] = W.Pop<std::string, std::string>();
	return W.Return(HttpPostJson(Url.c_str(), Data));
}

int Lua_HttpDownloadFile(lua_State * LP)
{
	auto W = xLuaStateWrapper(LP);
    auto [Url, Filename] = W.Pop<std::string, std::string>();
	return W.Return(HttpDownloadFile(Url.c_str(), Filename.c_str()));
}
