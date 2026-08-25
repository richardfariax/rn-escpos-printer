#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNEscPosCommands : NSObject

+ (nullable NSData *)textData:(NSString *)text
                    codePage:(NSString *)codePage
                    feedLines:(NSInteger)feedLines
                           cut:(BOOL)cut
                         error:(NSError **)error;
+ (NSData *)initializePrinter;
+ (NSData *)setLineSpacing24;
+ (NSData *)defaultLineSpacing;
+ (NSData *)bitImageHeaderForWidth:(NSInteger)width;
+ (NSData *)finishWithFeedLines:(NSInteger)feedLines cut:(BOOL)cut;

@end

NS_ASSUME_NONNULL_END
