#import "RnEscposPrinter.h"

#import "RNEscPosBluetoothTransport.h"
#import "RNEscPosCommands.h"
#import "RNEscPosErrors.h"
#import "RNEscPosImageEncoder.h"

typedef void (^RNEscPosStartErrorOperation)(RNEscPosErrorCompletion completion);

@interface RnEscposPrinter ()

@property(nonatomic, strong) RNEscPosBluetoothTransport *transport;
@property(nonatomic, strong) dispatch_queue_t operationQueue;

@end

@implementation RnEscposPrinter

- (instancetype)init
{
  self = [super init];
  if (self != nil) {
    _transport = [[RNEscPosBluetoothTransport alloc] init];
    _operationQueue =
        dispatch_queue_create("com.highsoft.rnescposprinter.operations", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)initialize:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject
{
  [self enqueueErrorOperationWithWait:12
                              starter:^(RNEscPosErrorCompletion completion) {
                                [self.transport initializeWithTimeout:10 completion:completion];
                              }
                              resolve:resolve
                               reject:reject];
}

- (void)getPrinters:(double)scanDurationMs
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject
{
  dispatch_async(self.operationQueue, ^{
    __block NSArray<NSDictionary<NSString *, id> *> *printers = nil;
    __block NSError *operationError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.transport scanWithDuration:scanDurationMs / 1000.0
                          completion:^(NSArray<NSDictionary<NSString *, id> *> *result,
                                       NSError *error) {
                            printers = result;
                            operationError = error;
                            dispatch_semaphore_signal(semaphore);
                          }];
    BOOL timedOut = dispatch_semaphore_wait(
                        semaphore,
                        dispatch_time(
                            DISPATCH_TIME_NOW,
                            (int64_t)((scanDurationMs / 1000.0 + 3) * NSEC_PER_SEC))) != 0;
    if (timedOut) {
      operationError = RNEscPosMakeError(
          @"ERR_SCAN_FAILED", @"The BLE scan did not finish", nil);
    }
    [self resolve:resolve reject:reject value:printers error:operationError];
  });
}

- (void)connect:(NSString *)identifier
      timeoutMs:(double)timeoutMs
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject
{
  [self enqueueErrorOperationWithWait:timeoutMs / 1000.0 + 3
                              starter:^(RNEscPosErrorCompletion completion) {
                                [self.transport connectToIdentifier:identifier
                                                           timeout:timeoutMs / 1000.0
                                                        completion:completion];
                              }
                              resolve:resolve
                               reject:reject];
}

- (void)disconnect:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject
{
  dispatch_async(self.operationQueue, ^{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.transport disconnectWithCompletion:^{
      dispatch_semaphore_signal(semaphore);
    }];
    BOOL timedOut = dispatch_semaphore_wait(
                        semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) != 0;
    NSError *error = timedOut
        ? RNEscPosMakeError(
              @"ERR_CONNECTION_FAILED", @"The BLE disconnect operation timed out", nil)
        : nil;
    [self resolve:resolve reject:reject value:nil error:error];
  });
}

- (void)isConnected:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject
{
  dispatch_async(self.operationQueue, ^{
    __block BOOL connected = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.transport isConnectedWithCompletion:^(BOOL value) {
      connected = value;
      dispatch_semaphore_signal(semaphore);
    }];
    BOOL timedOut = dispatch_semaphore_wait(
                        semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) != 0;
    NSError *error = timedOut
        ? RNEscPosMakeError(
              @"ERR_CONNECTION_FAILED", @"Could not read the BLE connection state", nil)
        : nil;
    [self resolve:resolve reject:reject value:@(connected) error:error];
  });
}

- (void)printText:(NSString *)text
          codePage:(NSString *)codePage
         feedLines:(double)feedLines
               cut:(BOOL)cut
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  dispatch_async(self.operationQueue, ^{
    NSError *encodingError = nil;
    NSData *data = [RNEscPosCommands textData:text
                                     codePage:codePage
                                     feedLines:(NSInteger)feedLines
                                            cut:cut
                                          error:&encodingError];
    if (data == nil) {
      [self reject:reject error:encodingError];
      return;
    }
    [self waitForWriteData:data timeout:60 resolve:resolve reject:reject];
  });
}

- (void)printImageBase64:(NSString *)base64
               paperWidth:(double)paperWidth
                 threshold:(double)threshold
                 feedLines:(double)feedLines
                       cut:(BOOL)cut
                   resolve:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject
{
  dispatch_async(self.operationQueue, ^{
    NSError *encodingError = nil;
    NSData *data = [RNEscPosImageEncoder dataFromBase64:base64
                                             paperWidth:(NSInteger)paperWidth
                                               threshold:(NSInteger)threshold
                                               feedLines:(NSInteger)feedLines
                                                      cut:cut
                                                    error:&encodingError];
    if (data == nil) {
      [self reject:reject error:encodingError];
      return;
    }
    [self waitForWriteData:data timeout:180 resolve:resolve reject:reject];
  });
}

- (void)invalidate
{
  [self.transport invalidate];
}

- (void)enqueueErrorOperationWithWait:(NSTimeInterval)wait
                               starter:(RNEscPosStartErrorOperation)starter
                               resolve:(RCTPromiseResolveBlock)resolve
                                reject:(RCTPromiseRejectBlock)reject
{
  dispatch_async(self.operationQueue, ^{
    __block NSError *operationError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    starter(^(NSError *error) {
      operationError = error;
      dispatch_semaphore_signal(semaphore);
    });
    BOOL timedOut = dispatch_semaphore_wait(
                        semaphore,
                        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC))) != 0;
    if (timedOut) {
      operationError = RNEscPosMakeError(
          @"ERR_CONNECTION_TIMEOUT", @"The native Bluetooth operation timed out", nil);
    }
    [self resolve:resolve reject:reject value:nil error:operationError];
  });
}

- (void)waitForWriteData:(NSData *)data
                  timeout:(NSTimeInterval)timeout
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject
{
  __block NSError *writeError = nil;
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  [self.transport writeData:data
                    timeout:timeout
                 completion:^(NSError *error) {
                   writeError = error;
                   dispatch_semaphore_signal(semaphore);
                 }];
  BOOL timedOut = dispatch_semaphore_wait(
                      semaphore,
                      dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 3) * NSEC_PER_SEC))) != 0;
  if (timedOut) {
    writeError =
        RNEscPosMakeError(@"ERR_WRITE_FAILED", @"The native print operation timed out", nil);
  }
  [self resolve:resolve reject:reject value:nil error:writeError];
}

- (void)resolve:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject
           value:(id)value
           error:(NSError *)error
{
  if (error != nil) {
    [self reject:reject error:error];
  } else {
    resolve(value);
  }
}

- (void)reject:(RCTPromiseRejectBlock)reject error:(NSError *)error
{
  NSError *safeError = error ?: RNEscPosMakeError(
                                    @"ERR_WRITE_FAILED", @"Unknown ESC/POS printer error", nil);
  NSString *code = safeError.userInfo[RNEscPosErrorCodeKey] ?: @"ERR_WRITE_FAILED";
  reject(code, safeError.localizedDescription, safeError);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeRnEscposPrinterSpecJSI>(params);
}

+ (NSString *)moduleName
{
  return @"RnEscposPrinter";
}

@end
