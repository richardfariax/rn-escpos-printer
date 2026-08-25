#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "../../../ios/RNEscPosImageEncoder.h"

@interface RNEscPosImageEncoder (Testing)

+ (NSData *)dataFromGrayscalePixels:(NSData *)pixels
                               width:(NSInteger)width
                              height:(NSInteger)height
                           threshold:(NSInteger)threshold
                           feedLines:(NSInteger)feedLines
                                 cut:(BOOL)cut;

@end

@interface RNEscPosImageEncoderTests : XCTestCase

@end


@implementation RNEscPosImageEncoderTests

- (void)testTopLeftPixelsAreEncodedInTheFirstStripe
{
  const NSInteger width = 384;
  const NSInteger height = 72;
  NSString *base64 = [self base64ImageWithWidth:width
                                         height:height
                                        drawing:^{
                                          [[UIColor blackColor] setFill];
                                          UIRectFill(CGRectMake(0, 0, 8, 8));
                                          UIRectFill(CGRectMake(width - 8, height - 8, 8, 8));
                                        }];

  NSError *error = nil;
  NSData *encoded = [RNEscPosImageEncoder dataFromBase64:base64
                                               paperWidth:58
                                                 threshold:160
                                                 feedLines:0
                                                        cut:NO
                                                      error:&error];

  XCTAssertNotNil(encoded);
  XCTAssertNil(error);
  const uint8_t *bytes = (const uint8_t *)encoded.bytes;
  const NSUInteger firstStripeDataOffset = 10;
  const NSUInteger stripeLength = 5 + (NSUInteger)width * 3 + 1;
  const NSUInteger lastStripeDataOffset = 5 + 2 * stripeLength + 5;
  XCTAssertEqual(bytes[firstStripeDataOffset], 0xFF);
  XCTAssertEqual(bytes[firstStripeDataOffset + 1], 0x00);
  XCTAssertEqual(bytes[firstStripeDataOffset + 2], 0x00);
  XCTAssertEqual(bytes[lastStripeDataOffset], 0x00);
  XCTAssertEqual(bytes[lastStripeDataOffset + 1], 0x00);
  XCTAssertEqual(bytes[lastStripeDataOffset + 2], 0x00);
  XCTAssertEqual(bytes[lastStripeDataOffset + (width - 8) * 3 + 2], 0xFF);
}

- (void)testTwentyFourDotFixtureMatchesGoldenEscPosBytes
{
  enum {
    width = 24,
    height = 24,
  };
  uint8_t pixels[width * height];
  memset(pixels, 0xFF, sizeof(pixels));
  pixels[0] = 0;
  pixels[7 * width] = 0;
  pixels[8 * width] = 0;
  pixels[15 * width] = 0;
  pixels[16 * width] = 0;
  pixels[23 * width] = 0;

  NSData *encoded = [RNEscPosImageEncoder
      dataFromGrayscalePixels:[NSData dataWithBytes:pixels length:sizeof(pixels)]
                         width:width
                        height:height
                     threshold:160
                     feedLines:0
                           cut:NO];
  static const uint8_t expected[85] = {
      0x1B, '@', 0x1B, '3', 24, 0x1B, '*', 33, 24, 0, 0x81, 0x81, 0x81,
      [82] = '\n', [83] = 0x1B, [84] = '2',
  };

  XCTAssertEqualObjects(encoded, [NSData dataWithBytes:expected length:sizeof(expected)]);
}

- (void)testRawBase64AndDataUriEncodeSupportedPaperWidths
{
  [self assertImageWidth:384 paperWidth:58];
  [self assertImageWidth:576 paperWidth:80];
}

- (void)assertImageWidth:(NSInteger)imageWidth paperWidth:(NSInteger)paperWidth
{
  NSString *rawBase64 = [self base64ImageWithWidth:imageWidth height:24 drawing:^{}];
  NSArray<NSString *> *values = @[
    rawBase64,
    [@"data:image/png;base64," stringByAppendingString:rawBase64],
  ];

  NSData *firstEncoding = nil;
  for (NSString *value in values) {
    NSError *error = nil;
    NSData *encoded = [RNEscPosImageEncoder dataFromBase64:value
                                                 paperWidth:paperWidth
                                                   threshold:160
                                                   feedLines:0
                                                          cut:NO
                                                        error:&error];

    XCTAssertNotNil(encoded);
    XCTAssertNil(error);
    XCTAssertEqual(encoded.length, (NSUInteger)imageWidth * 3 + 13);
    const uint8_t *bytes = (const uint8_t *)encoded.bytes;
    XCTAssertEqual(bytes[5], 0x1B);
    XCTAssertEqual(bytes[6], '*');
    XCTAssertEqual(bytes[7], 33);
    XCTAssertEqual(bytes[8], imageWidth & 0xFF);
    XCTAssertEqual(bytes[9], (imageWidth >> 8) & 0xFF);
    XCTAssertEqual(bytes[10], 0x00);
    XCTAssertEqual(bytes[10 + (imageWidth - 1) * 3 + 2], 0x00);

    if (firstEncoding == nil) {
      firstEncoding = encoded;
    } else {
      XCTAssertEqualObjects(encoded, firstEncoding);
    }
  }
}

- (NSString *)base64ImageWithWidth:(NSInteger)width
                            height:(NSInteger)height
                           drawing:(void (^)(void))drawing
{
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.opaque = YES;
  format.scale = 1;
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(width, height) format:format];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [[UIColor whiteColor] setFill];
    [context fillRect:CGRectMake(0, 0, width, height)];
    drawing();
  }];
  NSData *pngData = UIImagePNGRepresentation(image);
  XCTAssertNotNil(pngData);
  return [pngData base64EncodedStringWithOptions:0];
}

@end
