#import <XCTest/XCTest.h>

#import "../../../ios/RNEscPosCommands.h"

@interface RNEscPosCommandsTests : XCTestCase

@end

@implementation RNEscPosCommandsTests

- (void)testPortugueseTextUsesCP860GoldenBytes
{
  NSError *error = nil;
  NSData *encoded = [RNEscPosCommands textData:@"Não|RAZÃO|ORÇAMENTO|ação|café|preço"
                                      codePage:@"cp860"
                                     feedLines:0
                                            cut:NO
                                          error:&error];
  static const uint8_t expected[] = {
      0x1B, '@', 0x1B, 't', 3,
      0x4E, 0x84, 0x6F, 0x7C,
      0x52, 0x41, 0x5A, 0x8E, 0x4F, 0x7C,
      0x4F, 0x52, 0x80, 0x41, 0x4D, 0x45, 0x4E, 0x54, 0x4F, 0x7C,
      0x61, 0x87, 0x84, 0x6F, 0x7C,
      0x63, 0x61, 0x66, 0x82, 0x7C,
      0x70, 0x72, 0x65, 0x87, 0x6F,
  };

  XCTAssertNil(error);
  XCTAssertEqualObjects(encoded, [NSData dataWithBytes:expected length:sizeof(expected)]);
}

@end
