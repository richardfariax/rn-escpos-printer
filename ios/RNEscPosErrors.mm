#import "RNEscPosErrors.h"

NSString *const RNEscPosErrorDomain = @"RnEscposPrinter";
NSString *const RNEscPosErrorCodeKey = @"RnEscposPrinterErrorCode";

NSError *RNEscPosMakeError(
    NSString *code,
    NSString *message,
    NSError *_Nullable underlyingError)
{
  NSMutableDictionary *userInfo = [@{
    NSLocalizedDescriptionKey : message,
    RNEscPosErrorCodeKey : code,
  } mutableCopy];
  if (underlyingError != nil) {
    userInfo[NSUnderlyingErrorKey] = underlyingError;
  }
  return [NSError errorWithDomain:RNEscPosErrorDomain code:1 userInfo:userInfo];
}
