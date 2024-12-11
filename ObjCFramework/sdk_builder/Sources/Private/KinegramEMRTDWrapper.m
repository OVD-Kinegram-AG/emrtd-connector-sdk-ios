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
                            completion:(KinegramEMRTDCompletionBlock)completion {
    [self.wrapper readPassportWithDocumentNumber:documentNumber
                                     dateOfBirth:dateOfBirth
                                    dateOfExpiry:dateOfExpiry
                                      completion:completion];
}

- (void)readPassportWithCan:(NSString *)can completion:(KinegramEMRTDCompletionBlock)completion {
    [self.wrapper readPassportWithCan:can completion:completion];
}

@end
