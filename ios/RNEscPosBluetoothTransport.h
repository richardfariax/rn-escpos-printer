#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^RNEscPosErrorCompletion)(NSError *_Nullable error);
typedef void (^RNEscPosPrintersCompletion)(
    NSArray<NSDictionary<NSString *, id> *> *_Nullable printers,
    NSError *_Nullable error);
typedef void (^RNEscPosBooleanCompletion)(BOOL value);

@interface RNEscPosBluetoothTransport : NSObject

- (void)initializeWithTimeout:(NSTimeInterval)timeout
                    completion:(RNEscPosErrorCompletion)completion;
- (void)scanWithDuration:(NSTimeInterval)duration
               completion:(RNEscPosPrintersCompletion)completion;
- (void)connectToIdentifier:(NSString *)identifier
                    timeout:(NSTimeInterval)timeout
                 completion:(RNEscPosErrorCompletion)completion;
- (void)disconnectWithCompletion:(dispatch_block_t)completion;
- (void)isConnectedWithCompletion:(RNEscPosBooleanCompletion)completion;
- (void)writeData:(NSData *)data
          timeout:(NSTimeInterval)timeout
       completion:(RNEscPosErrorCompletion)completion;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
