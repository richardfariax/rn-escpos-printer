#import "RNEscPosImageEncoder.h"

#import <UIKit/UIKit.h>

#import "RNEscPosCommands.h"
#import "RNEscPosErrors.h"

static const NSUInteger RNMaxBase64Length = 24000000;
static const NSInteger RNMaxImageHeight = 30000;

@implementation RNEscPosImageEncoder

+ (NSData *)dataFromBase64:(NSString *)base64
                 paperWidth:(NSInteger)paperWidth
                   threshold:(NSInteger)threshold
                   feedLines:(NSInteger)feedLines
                          cut:(BOOL)cut
                        error:(NSError **)error
{
  NSString *payload = [self payloadFromValue:base64];
  if (payload.length == 0 || payload.length > RNMaxBase64Length) {
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_IMAGE",
          @"The base64 image is empty or exceeds the 24 MB input limit",
          nil);
    }
    return nil;
  }

  NSData *imageData = [[NSData alloc]
      initWithBase64EncodedString:payload
                          options:NSDataBase64DecodingIgnoreUnknownCharacters];
  UIImage *image = imageData == nil ? nil : [UIImage imageWithData:imageData];
  if (image == nil || image.size.width <= 0 || image.size.height <= 0) {
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_IMAGE", @"Unsupported or invalid image data", nil);
    }
    return nil;
  }

  NSInteger targetWidth;
  if (paperWidth == 58) {
    targetWidth = 384;
  } else if (paperWidth == 80) {
    targetWidth = 576;
  } else {
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_ARGUMENT", @"Paper width must be 58 or 80", nil);
    }
    return nil;
  }

  NSInteger targetHeight = MAX(
      1,
      (NSInteger)llround(image.size.height * ((double)targetWidth / image.size.width)));
  if (targetHeight > RNMaxImageHeight) {
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_IMAGE",
          [NSString stringWithFormat:
                        @"The proportional image height exceeds %ld pixels",
                        (long)RNMaxImageHeight],
          nil);
    }
    return nil;
  }

  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.opaque = YES;
  format.scale = 1;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
      initWithSize:CGSizeMake(targetWidth, targetHeight)
             format:format];
  UIImage *scaled = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [[UIColor whiteColor] setFill];
    [context fillRect:CGRectMake(0, 0, targetWidth, targetHeight)];
    [image drawInRect:CGRectMake(0, 0, targetWidth, targetHeight)];
  }];

  size_t pixelCount = (size_t)targetWidth * (size_t)targetHeight;
  uint8_t *grayscale = (uint8_t *)calloc(pixelCount, sizeof(uint8_t));
  if (grayscale == NULL) {
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_IMAGE", @"The image is too large to process safely", nil);
    }
    return nil;
  }

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  CGContextRef bitmapContext = CGBitmapContextCreate(
      grayscale,
      (size_t)targetWidth,
      (size_t)targetHeight,
      8,
      (size_t)targetWidth,
      colorSpace,
      (CGBitmapInfo)kCGImageAlphaNone);
  CGColorSpaceRelease(colorSpace);
  if (bitmapContext == NULL || scaled.CGImage == nil) {
    if (bitmapContext != NULL) {
      CGContextRelease(bitmapContext);
    }
    free(grayscale);
    if (error != nil) {
      *error = RNEscPosMakeError(
          @"ERR_INVALID_IMAGE", @"The image bitmap could not be created", nil);
    }
    return nil;
  }

  CGContextSetGrayFillColor(bitmapContext, 1, 1);
  CGContextFillRect(bitmapContext, CGRectMake(0, 0, targetWidth, targetHeight));
  CGContextTranslateCTM(bitmapContext, 0, targetHeight);
  CGContextScaleCTM(bitmapContext, 1, -1);
  CGContextDrawImage(
      bitmapContext, CGRectMake(0, 0, targetWidth, targetHeight), scaled.CGImage);
  CGContextRelease(bitmapContext);

  NSMutableData *result = [NSMutableData data];
  [result appendData:[RNEscPosCommands initializePrinter]];
  [result appendData:[RNEscPosCommands setLineSpacing24]];
  for (NSInteger stripeTop = 0; stripeTop < targetHeight; stripeTop += 24) {
    [result appendData:[RNEscPosCommands bitImageHeaderForWidth:targetWidth]];
    for (NSInteger x = 0; x < targetWidth; x += 1) {
      for (NSInteger byteIndex = 0; byteIndex < 3; byteIndex += 1) {
        uint8_t imageByte = 0;
        for (NSInteger bit = 0; bit < 8; bit += 1) {
          NSInteger y = stripeTop + byteIndex * 8 + bit;
          if (y < targetHeight && grayscale[(size_t)y * targetWidth + x] < threshold) {
            imageByte |= (uint8_t)(1 << (7 - bit));
          }
        }
        [result appendBytes:&imageByte length:1];
      }
    }
    const uint8_t lineFeed = '\n';
    [result appendBytes:&lineFeed length:1];
  }
  free(grayscale);
  [result appendData:[RNEscPosCommands finishWithFeedLines:feedLines cut:cut]];
  return result;
}

+ (NSString *)payloadFromValue:(NSString *)value
{
  NSString *payload = value;
  if ([value hasPrefix:@"data:"]) {
    NSRange comma = [value rangeOfString:@","];
    if (comma.location != NSNotFound) {
      payload = [value substringFromIndex:comma.location + 1];
    }
  }
  NSArray<NSString *> *components =
      [payload componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return [components componentsJoinedByString:@""];
}

@end
