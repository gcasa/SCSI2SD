//
//  SettingsController.h
//  scsi2sd
//
//  Created by Gregory Casamento on 12/3/18.
//  Copyright © 2018 Open Logic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "ConfigUtil.hh"

NS_ASSUME_NONNULL_BEGIN

@interface SettingsController : NSObject

- (NSString *) toXml;
// - (void) fromXml: (NSXMLElement *)node;
- (void) setConfig: (BoardConfig)config;
- (BoardConfig) getConfig;

@end

NS_ASSUME_NONNULL_END
