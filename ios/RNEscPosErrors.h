#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const RNEscPosErrorDomain;
FOUNDATION_EXPORT NSString *const RNEscPosErrorCodeKey;

FOUNDATION_EXPORT NSError *RNEscPosMakeError(
    NSString *code,
    NSString *message,
    NSError *_Nullable underlyingError);

NS_ASSUME_NONNULL_END
