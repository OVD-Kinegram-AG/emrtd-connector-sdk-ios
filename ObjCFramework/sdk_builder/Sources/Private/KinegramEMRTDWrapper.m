//
//  KinegramEMRTDWrapper.m
//  KinegramEmrtdConnectorObjC
//
//  Created by Alexander Manzer on 10.12.24.
//

#import "KinegramEMRTDWrapper.h"
#import <KinegramEmrtdConnector/KinegramEmrtdConnector-Swift.h>

// Private Interface
@interface KinegramEMRTDWrapper ()
@property (nonatomic, strong) EmrtdConnectorObjCWrapper *wrapper;
@end

@implementation KinegramEMRTDWrapper

- (nullable instancetype)initWithClientId:(NSString *)clientId webSocketUrl:(NSString *)url {
    self = [super init];
    if (self) {
        self.wrapper = [[EmrtdConnectorObjCWrapper alloc] initWithClientId:clientId webSocketUrl:url];
        if (!self.wrapper) {
            return nil;
        }
    }
    return self;
}

- (void)readPassportWithDocumentNumber:(NSString *)documentNumber
                           dateOfBirth:(NSString *)dateOfBirth
                          dateOfExpiry:(NSString *)dateOfExpiry
                          validationId:(NSString *)validationId
                            completion:(KinegramEMRTDCompletionBlock)completion {
    [self.wrapper readPassportWithDocumentNumber:documentNumber
                                     dateOfBirth:dateOfBirth
                                    dateOfExpiry:dateOfExpiry
                                    validationId:validationId
                                      completion:completion];
}

- (void)readPassportWithCan:(NSString *)can
               validationId:(NSString *)validationId
                 completion:(KinegramEMRTDCompletionBlock)completion {
    [self.wrapper readPassportWithCan:can
                         validationId:validationId
                           completion:completion];
}

@end
