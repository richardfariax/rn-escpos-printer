#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNEscPosImageEncoder : NSObject

+ (nullable NSData *)dataFromBase64:(NSString *)base64
                         paperWidth:(NSInteger)paperWidth
                           threshold:(NSInteger)threshold
                           feedLines:(NSInteger)feedLines
                                  cut:(BOOL)cut
                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
