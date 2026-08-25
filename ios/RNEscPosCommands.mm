#import "RNEscPosCommands.h"

#import <CoreFoundation/CFStringEncodingExt.h>

#import "RNEscPosErrors.h"

static const uint8_t RNEsc = 0x1B;
static const uint8_t RNGs = 0x1D;

@implementation RNEscPosCommands

+ (NSData *)textData:(NSString *)text
            codePage:(NSString *)codePage
            feedLines:(NSInteger)feedLines
                   cut:(BOOL)cut
                 error:(NSError **)error
{
  CFStringEncoding cfEncoding;
  uint8_t codeTable;
  if ([codePage isEqualToString:@"cp850"]) {
    cfEncoding = kCFStringEncodingDOSLatin1;
    codeTable = 2;
  } else if ([codePage isEqualToString:@"cp860"]) {
    cfEncoding = kCFStringEncodingDOSPortuguese;
    codeTable = 3;
  } else if ([codePage isEqualToString:@"windows1252"]) {
    cfEncoding = kCFStringEncodingWindowsLatin1;
    codeTable = 16;
  } else {
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_ARGUMENT",
          [NSString stringWithFormat:@"Unsupported code page: %@", codePage],
          nil);
    }
    return nil;
  }

  NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
  NSData *encodedText = [text dataUsingEncoding:encoding allowLossyConversion:YES];
  if (encodedText == nil) {
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_ARGUMENT", @"The text could not be encoded", nil);
    }
    return nil;
  }

  NSMutableData *result = [NSMutableData data];
  [result appendData:[self initializePrinter]];
  const uint8_t selectCodeTable[] = {RNEsc, 't', codeTable};
  [result appendBytes:selectCodeTable length:sizeof(selectCodeTable)];
  [result appendData:encodedText];
  [self appendFeedLines:feedLines toData:result];
  if (cut) {
    [result appendData:[self partialCut]];
  }
  return result;
}

+ (NSData *)initializePrinter
{
  const uint8_t bytes[] = {RNEsc, '@'};
  return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSData *)setLineSpacing24
{
  const uint8_t bytes[] = {RNEsc, '3', 24};
  return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSData *)defaultLineSpacing
{
  const uint8_t bytes[] = {RNEsc, '2'};
  return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSData *)bitImageHeaderForWidth:(NSInteger)width
{
  const uint8_t bytes[] = {
      RNEsc,
      '*',
      33,
      (uint8_t)(width & 0xFF),
      (uint8_t)((width >> 8) & 0xFF),
  };
  return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSData *)finishWithFeedLines:(NSInteger)feedLines cut:(BOOL)cut
{
  NSMutableData *result = [[self defaultLineSpacing] mutableCopy];
  [self appendFeedLines:feedLines toData:result];
  if (cut) {
    [result appendData:[self partialCut]];
  }
  return result;
}

+ (void)appendFeedLines:(NSInteger)feedLines toData:(NSMutableData *)data
{
  const uint8_t lineFeed = '\n';
  for (NSInteger index = 0; index < feedLines; index += 1) {
    [data appendBytes:&lineFeed length:1];
  }
}

+ (NSData *)partialCut
{
  const uint8_t bytes[] = {RNGs, 'V', 66, 0};
  return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

@end
