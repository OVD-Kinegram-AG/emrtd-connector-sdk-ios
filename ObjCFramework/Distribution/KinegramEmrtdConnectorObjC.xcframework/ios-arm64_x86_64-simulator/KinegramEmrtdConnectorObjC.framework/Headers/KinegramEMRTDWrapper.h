//
//  KinegramEMRTDWrapper.h
//  KinegramEmrtdConnectorObjC
//
//  Created by Alexander Manzer on 10.12.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^KinegramEMRTDCompletionBlock)(NSString * _Nullable passportJson, NSError * _Nullable error);

@interface KinegramEMRTDWrapper : NSObject

- (nullable instancetype)initWithClientId:(NSString *)clientId
                             webSocketUrl:(NSString *)url;

- (void)readPassportWithDocumentNumber:(NSString *)documentNumber
                           dateOfBirth:(NSString *)dateOfBirth
                          dateOfExpiry:(NSString *)dateOfExpiry
                            completion:(KinegramEMRTDCompletionBlock)completion;

- (void)readPassportWithCan:(NSString *)can
                 completion:(KinegramEMRTDCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
