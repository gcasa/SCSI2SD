//
//  SCSI2SDTask.m
//  scsi2sd-util-cli
//
//  Created by Gregory Casamento on 1/10/20.
//  Copyright © 2020 Rabbit Hole Computing, LLC. All rights reserved.
//

#import "SCSI2SDTask.hh"
#import "zipper.hh"

#define MIN_FIRMWARE_VERSION 0x0400
#define MIN_FIRMWARE_VERSION 0x0400

static uint8_t sdCrc7(uint8_t* chr, uint8_t cnt, uint8_t crc)
{
    uint8_t a;
    for(a = 0; a < cnt; a++)
    {
        uint8_t data = chr[a];
        uint8_t i;
        for(i = 0; i < 8; i++)
        {
            crc <<= 1;
            if ((data & 0x80) ^ (crc & 0x80))
            {
                crc ^= 0x09;
            }
            data <<= 1;
        }
    }
    return crc & 0x7F;
}

@implementation SCSI2SDTask

+ (instancetype) task
{
    SCSI2SDTask *task = [[SCSI2SDTask alloc] init];
    // [task autorelease];
    return task;
}

- (instancetype) init
{
    self = [super init];
    if(self)
    {
        self.repeatMode = NO;
    }
    return self;
}


- (void) logStringToPanel: (NSString *)s
{
    const char *string = [s cStringUsingEncoding:NSUTF8StringEncoding];
    printf("%s",string);
}

// Update progress...
- (NSString *) percentString: (NSNumber *)prog
{
    NSUInteger n = [prog unsignedIntegerValue];
    
    NSString *t1 = (n >= 10) ? @"X" :  @"-";
    NSString *t11 = (n >= 15) ? @"X" :  @"-";
    NSString *t2 = (n >= 20) ? @"X" :  @"-";
    NSString *t21 = (n >= 25) ? @"X" :  @"-";
    NSString *t3 = (n >= 30) ? @"X" :  @"-";
    NSString *t31 = (n >= 35) ? @"X" :  @"-";
    NSString *t4 = (n >= 40) ? @"X" :  @"-";
    NSString *t41 = (n >= 45) ? @"X" :  @"-";
    NSString *t5 = (n >= 50) ? @"X" :  @"-";
    NSString *t51 = (n >= 55) ? @"X" :  @"-";
    NSString *t6 = (n >= 60) ? @"X" :  @"-";
    NSString *t61 = (n >= 65) ? @"X" :  @"-";
    NSString *t7 = (n >= 70) ? @"X" :  @"-";
    NSString *t71 = (n >= 75) ? @"X" :  @"-";
    NSString *t8 = (n >= 80) ? @"X" :  @"-";
    NSString *t81 = (n >= 85) ? @"X" :  @"-";
    NSString *t9 = (n >= 90) ? @"X" :  @"-";
    NSString *t91 = (n >= 95) ? @"X" :  @"-";
    NSString *t10 = (n >= 100) ? @"X" :  @"-";
    NSString *percString = [NSString stringWithFormat:
                            @"[%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@] %3u%%\r",
                            t1,
                            t11,
                            t2,
                            t21,
                            t3,
                            t31,
                            t4,
                            t41,
                            t5,
                            t51,
                            t6,
                            t61,
                            t7,
                            t71,
                            t8,
                            t81,
                            t9,
                            t91,
                            t10,
                            (unsigned int)n];
    return percString;
}

- (void) updateProgress: (NSNumber *)prog
{
    //self.logTextView.string =
    //    [self.logTextView.string substringToIndex: [self.logTextView.string length] - 24];
    [self logStringToPanel: [self percentString:prog]];
}

// Reset the HID...
- (void) reset_hid
{
    try
    {
        myHID = SCSI2SD::HID::Open();
        // myHID.reset(SCSI2SD::HID::Open());
        if(myHID)
        {
            NSString *msg = [NSString stringWithFormat: @"SCSI2SD Ready, firmware version %s",myHID->getFirmwareVersionStr().c_str()];
            [self logStringToPanel:msg];
        }
    }
    catch (std::exception& e)
    {
        [self logStringToPanel: [NSString stringWithFormat: @"\nException caught: %s",e.what()]];
    }
}

- (void) reset_bootloader
{
    try
    {
        myBootloader = SCSI2SD::Bootloader::Open();
    }
    catch (std::exception& e)
    {
        [self logStringToPanel: [NSString stringWithFormat: @"\nBootloader Exception caught: %s",e.what()]];
    }
}

- (BOOL) getHid
{
    BOOL gotHID = NO;
    // Check if we are connected to the HID device.
    // AND/or bootloader device.
    try
    {
        if (myBootloader)
        {
            // Verify the USB HID connection is valid
            if (!myBootloader->ping())
            {
                [self reset_bootloader];
            }
        }

        if (!myBootloader)
        {
            [self reset_bootloader];
            if (myBootloader)
            {
                gotHID = YES;
            }
        }
        else
        {
            gotHID = YES;
        }

        BOOL supressLog = NO;
        if (myHID && myHID->getFirmwareVersion() < MIN_FIRMWARE_VERSION)
        {
            // No method to check connection is still valid.
            [self reset_hid];
            gotHID = YES;
        }
        else if (myHID && !myHID->ping())
        {
            // Verify the USB HID connection is valid
            [self reset_hid];
        }
        else
        {
            if(myHID)
            {
                gotHID = YES;
            }
        }
        
        // Show that we got the HID acquired...
        /*if(gotHID && self.repeatMode)
        {
            NSString *msg = [NSString stringWithFormat: @"\nSCSI2SD Ready, firmware version %s",myHID->getFirmwareVersionStr().c_str()];
            [self logStringToPanel:msg];
        }*/
        
        if (!myHID)
        {
            [self reset_hid];
            if (myHID)
            {
                if (myHID->getFirmwareVersion() < MIN_FIRMWARE_VERSION)
                {
                    if (!supressLog)
                    {
                        // Oh dear, old firmware
                        NSString *log = [NSString stringWithFormat: @"\nFirmware update required.  Version %s",myHID->getFirmwareVersionStr().c_str()];
                        [self logStringToPanel: log];
                    }
                }
                else
                {
                    NSString *msg = @"";
                    /*
                    NSString *msg = [NSString stringWithFormat: @"\nSCSI2SD Ready, firmware version %s",myHID->getFirmwareVersionStr().c_str()];
                    [self logStringToPanel:msg];
                     */
                    std::vector<uint8_t> csd(myHID->getSD_CSD());
                    std::vector<uint8_t> cid(myHID->getSD_CID());
                    msg = [NSString stringWithFormat: @"\nSD Capacity (512-byte sectors): %d",
                        myHID->getSDCapacity()];
                    [self logStringToPanel:msg];

                    msg = [NSString stringWithFormat: @"\nSD CSD Register: "];
                    [self logStringToPanel:msg];
                    if (sdCrc7(&csd[0], 15, 0) != (csd[15] >> 1))
                    {
                        msg = [NSString stringWithFormat: @"BADCRC"];
                        [self logStringToPanel:msg];
                    }
                    for (size_t i = 0; i < csd.size(); ++i)
                    {
                        [self logStringToPanel:[NSString stringWithFormat: @"%x", static_cast<int>(csd[i])]];
                    }
                    msg = [NSString stringWithFormat: @"\nSD CID Register: "];
                    [self logStringToPanel:msg];
                    if (sdCrc7(&cid[0], 15, 0) != (cid[15] >> 1))
                    {
                        msg = [NSString stringWithFormat: @"BADCRC"];
                        [self logStringToPanel:msg];
                    }
                    for (size_t i = 0; i < cid.size(); ++i)
                    {
                        [self logStringToPanel:[NSString stringWithFormat: @"%x", static_cast<int>(cid[i])]];
                    }
                    [self logStringToPanel:@"\n"];
                }
            }
        }
    }
    catch (std::runtime_error& e)
    {
        [self logStringToPanel:[NSString stringWithFormat:@"%s", e.what()]];
        return NO;
    }
    return gotHID;
}

- (void) waitForHidConnection
{
    puts("\nWaiting for HID connect...");
    while(![self getHid])
    {
        // nothing to do...
    }
}

- (void)saveConfigs: (std::pair<BoardConfig, std::vector<TargetConfig>>)configs
             toFile: (NSString *)filename
{
    if([filename isEqualToString:@""] || filename == nil)
    return;

    NSString *outputString = @"";
    outputString = [outputString stringByAppendingString: @"<SCSI2SD>\n"];
    std::string s = SCSI2SD::ConfigUtil::toXML(configs.first);
    NSString *string = [NSString stringWithCString:s.c_str() encoding:NSUTF8StringEncoding];
    outputString = [outputString stringByAppendingString:string];

    NSUInteger i = 0;
    for(i = 0; i < configs.second.size(); i++)
    {
        std::string s = SCSI2SD::ConfigUtil::toXML(configs.second[i]);
        NSString *string = [NSString stringWithCString:s.c_str() encoding:NSUTF8StringEncoding];
        outputString = [outputString stringByAppendingString:string];
    }
    outputString = [outputString stringByAppendingString: @"</SCSI2SD>\n"];
    NSError *err = nil;
    [outputString writeToFile:filename atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (err != nil)
    {
        NSString *error = [err localizedDescription];
        puts([error cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    else
    {
        puts("Save complete");
    }
}

#define NUM_DEVS 4
- (void) saveFromDeviceFromFilename: (NSString *)filename
{
    BOOL gotHID = [self getHid];
    if(gotHID == NO)
    {
        [self logStringToPanel:@"Couldn't initialize HID configuration"];
        return;
    }
    
    if (!myHID) // goto out;
    {
        [self reset_hid];
    }
    
    if(!myHID)
    {
        [self logStringToPanel: @"Couldn't initialize HID configuration"];
    }

    /*
    [self performSelectorOnMainThread: @selector(logStringToPanel:)
                           withObject:@"Loading configuration"
                        waitUntilDone:YES];
    
    [self performSelectorOnMainThread: @selector(logStringToPanel:)
                           withObject:@"Load config settings"
                        waitUntilDone:YES];
    */
    std::pair<BoardConfig, std::vector<TargetConfig>> configs;

    int currentProgress = 0;
    int totalProgress = (int)(NUM_DEVS * (NSUInteger)SCSI_CONFIG_ROWS + (NSUInteger)1);

    // Read board config first.
    std::vector<uint8_t> boardCfgFlashData;
    int flashRow = SCSI_CONFIG_BOARD_ROW;
    {
        /*
        NSString *ss = [NSString stringWithFormat:
                        @"\rReading flash array %d row %d", SCSI_CONFIG_ARRAY, flashRow + 1];
        [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                withObject:ss
                             waitUntilDone:YES];*/
        currentProgress += 1;
        try
        {
            myHID->readFlashRow(
                SCSI_CONFIG_ARRAY, flashRow, boardCfgFlashData);
            BoardConfig bConfig = SCSI2SD::ConfigUtil::boardConfigFromBytes(&boardCfgFlashData[0]);
            configs.first = bConfig;
        }
        catch (std::runtime_error& e)
        {
            NSString *ss = [NSString stringWithFormat:
                            @"\n\nException: %s\n\n",e.what()];
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                    withObject:ss
                                 waitUntilDone:YES];
            goto err;
        }
    }
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconversion"
    for (size_t i = 0; i < NUM_DEVS; ++i)
    {
        flashRow = (i <= 3)
            ? SCSI_CONFIG_0_ROW + (i*SCSI_CONFIG_ROWS)
            : SCSI_CONFIG_4_ROW + ((i-4)*SCSI_CONFIG_ROWS);
        std::vector<uint8_t> raw(sizeof(TargetConfig));

        for (size_t j = 0; j < SCSI_CONFIG_ROWS; ++j)
        {
            /*
            NSString *ss = [NSString stringWithFormat:
                            @"\nReading flash array %d row %d", SCSI_CONFIG_ARRAY, flashRow + 1];
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                    withObject:ss
                                 waitUntilDone:YES]; */
            currentProgress += 1;
            if (currentProgress == totalProgress)
            {
                [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                        withObject:@"\nRead Complete."
                                     waitUntilDone:YES];
            }
            [self performSelectorOnMainThread:@selector(updateProgress:)
                                   withObject:[NSNumber numberWithDouble:(double)currentProgress]
                                waitUntilDone:NO];
            
            std::vector<uint8_t> flashData;
            try
            {
                myHID->readFlashRow(
                    SCSI_CONFIG_ARRAY, flashRow + j, flashData);

            }
            catch (std::runtime_error& e)
            {
                [self logStringToPanel: [NSString stringWithFormat: @"Exception caught: %s",e.what()]];
                goto err;
            }

            std::copy(
                flashData.begin(),
                flashData.end(),
                &raw[j * SCSI_CONFIG_ROW_SIZE]);
        }
#pragma GCC diagnostic pop
        TargetConfig tConfig = SCSI2SD::ConfigUtil::fromBytes(&raw[0]);
        configs.second.push_back(tConfig);
    }

    // Support old boards without board config set
    /*
    if (memcmp(&boardCfgFlashData[0], "BCFG", 4)) {
        BoardConfig defCfg = SCSI2SD::ConfigUtil::DefaultBoardConfig();
        defCfg.flags = [[deviceControllers objectAtIndex:0] getTargetConfig].flagsDEPRECATED;
        [_settings setConfig:defCfg];
    }*/

    // myInitialConfig = true;
    
    [self saveConfigs:configs toFile:filename]; // output xml...
    goto out;

err:
    [self logStringToPanel: @"\nSave failed"];
    goto out;

out:
    [self logStringToPanel: @"\nSave successful\n"];
    return;
}



- (void) saveToDeviceFromFilename: (NSString *)filename
{
    if(filename == nil || [filename isEqualToString:@""])
    {
        return;
    }
 
    [self getHid];
    std::pair<BoardConfig, std::vector<TargetConfig>> configs =
        SCSI2SD::ConfigUtil::fromXML([filename cStringUsingEncoding:NSUTF8StringEncoding]);
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:0.0]
                        waitUntilDone:NO];

    if (!myHID) return;

    [self performSelectorOnMainThread: @selector(logStringToPanel:)
                            withObject: @"\nSaving configuration\n"
                         waitUntilDone:YES];
    int currentProgress = 0;
    int totalProgress = (int)configs.second.size() * SCSI_CONFIG_ROWS + 1;

    // Write board config first.
    int flashRow = SCSI_CONFIG_BOARD_ROW;
    {
        /*
        NSString *ss = [NSString stringWithFormat:
                        @"Programming flash array %d row %d", SCSI_CONFIG_ARRAY, flashRow + 1];
        [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                withObject:ss
                             waitUntilDone:YES]; */
        currentProgress += 1;
        [self performSelectorOnMainThread:@selector(updateProgress:)
                               withObject:[NSNumber numberWithDouble: (double)totalProgress]
                            waitUntilDone:NO];

        std::vector<uint8_t> flashData = SCSI2SD::ConfigUtil::boardConfigToBytes(configs.first);
        try
        {
            myHID->writeFlashRow(
                SCSI_CONFIG_ARRAY, flashRow, flashData);
        }
        catch (std::runtime_error& e)
        {
             [self logStringToPanel: [NSString stringWithFormat: @"Exception caught: %s",e.what()]];
            goto err;
        }
    }

    flashRow = SCSI_CONFIG_0_ROW;
    for (size_t i = 0;
        i < configs.second.size();
        ++i)
    {
        flashRow = (i <= 3)
            ? SCSI_CONFIG_0_ROW + ((int)i*SCSI_CONFIG_ROWS)
            : SCSI_CONFIG_4_ROW + ((int)(i-4)*SCSI_CONFIG_ROWS);

        TargetConfig config(configs.second[i]);
        std::vector<uint8_t> raw(SCSI2SD::ConfigUtil::toBytes(config));

        for (size_t j = 0; j < SCSI_CONFIG_ROWS; ++j)
        {
            /*
            NSString *ss = [NSString stringWithFormat:
                            @"Programming flash array %d row %d", SCSI_CONFIG_ARRAY, flashRow + 1];
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                    withObject:ss
                                 waitUntilDone:YES]; */

            currentProgress += 1;
            if (currentProgress == totalProgress)
            {
                [self performSelectorOnMainThread:@selector(logStringToPanel:)
                                       withObject:@"\nLoad complete\n"
                                    waitUntilDone:YES];
            }
            /*
            [self performSelectorOnMainThread:@selector(updateProgress:)
                                   withObject:[NSNumber numberWithDouble: (double)totalProgress]
                                waitUntilDone:NO]; */

            std::vector<uint8_t> flashData(SCSI_CONFIG_ROW_SIZE, 0);
            std::copy(
                &raw[j * SCSI_CONFIG_ROW_SIZE],
                &raw[(1+j) * SCSI_CONFIG_ROW_SIZE],
                flashData.begin());
            try
            {
                myHID->writeFlashRow(
                    SCSI_CONFIG_ARRAY, (int)flashRow + (int)j, flashData);
            }
            catch (std::runtime_error& e)
            {
                NSString *ss = [NSString stringWithFormat:
                                @"Error: %s", e.what()];
                [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                        withObject:ss
                                     waitUntilDone:YES];
                goto err;
            }
        }
    }

    // [self reset_hid];
        //myHID = SCSI2SD::HID::Open();
    goto out;

err:
    /*
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble: (double)100.0]
                        waitUntilDone:NO];*/
    [self performSelectorOnMainThread: @selector(logStringToPanel:)
                            withObject:@"\nSave Failed\n"
                         waitUntilDone:YES];
    goto out;

out:
    /*
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble: (double)100.0]
                        waitUntilDone:NO];*/

    return;
}

- (void) upgradeFirmwareDeviceFromFilename: (NSString *)filename
{
    if(filename != nil)
    {
        int prog = 0;
        while (true)
        {
            try
            {
                if (!myHID)
                {
                    [self reset_hid];
                }
                
                if (myHID)
                {
                    [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                            withObject: @"Resetting SCSI2SD Into Bootloader\n"
                                         waitUntilDone:YES];
                    myHID->enterBootloader();
                }

                if (!myBootloader)
                {
                    [self reset_bootloader];
                    if (myBootloader)
                    {
                        [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                                withObject: @"Bootloader found\n"
                                             waitUntilDone:YES];
                        break;
                    }
                }
                else if (myBootloader)
                {
                    if (!myBootloader->ping())
                    {
                        [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                                withObject: @"Bootloader ping failed\n"
                                             waitUntilDone:YES];
                    }
                    else
                    {
                        [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                                withObject: @"Bootloader found\n"
                                             waitUntilDone:YES];
                        break;
                    }
                }
            }
            catch (std::exception& e)
            {
                NSLog(@"%s",e.what());
                [self reset_hid];
            }
            [NSThread sleepForTimeInterval:0.1];
        }

        int totalFlashRows = 0;
        NSString *tmpFile = [NSHomeDirectory()
                             stringByAppendingPathComponent:
                             [NSString stringWithFormat:
                              @"\nSCSI2SD_Firmware-%f.scsi2sd\n",
                              [[NSDate date] timeIntervalSince1970]]];
        std::string name = std::string([tmpFile cStringUsingEncoding:NSASCIIStringEncoding]);
        
        try
        {
            zipper::ReaderPtr reader(new zipper::FileReader([filename cStringUsingEncoding:NSASCIIStringEncoding]));
            zipper::Decompressor decomp(reader);
            std::vector<zipper::CompressedFilePtr> files(decomp.getEntries());
                        
            for (auto it(files.begin());it != files.end(); it++)
            {
                if (myBootloader && myBootloader->isCorrectFirmware((*it)->getPath()))
                {
                    NSString *ss = [NSString stringWithFormat:
                                    @"\nFound firmware entry %s within archive %@\n",
                                    (*it)->getPath().c_str(), filename];
                    [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                            withObject: ss
                                         waitUntilDone:YES];
                    
                    zipper::FileWriter out(name);
                    (*it)->decompress(out);
                    NSString *msg = [NSString stringWithFormat:
                                     @"\nFirmware extracted to %@\n",tmpFile];
                    [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                            withObject: msg
                                         waitUntilDone:YES];
                    break;
                }
            }

            if ([tmpFile isEqualToString:@""])
            {
                [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                        withObject: @"\nWrong filename\n"
                                     waitUntilDone:YES];
                return;
            }

            SCSI2SD::Firmware firmware(name);
            totalFlashRows = firmware.totalFlashRows();
        }
        catch (std::exception& e)
        {
            NSString *msg = [NSString stringWithFormat:@"Could not open firmware file: %s\n",e.what()];
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                    withObject:msg
                                 waitUntilDone:YES];
            return;
        }

        [self performSelectorOnMainThread:@selector(updateProgress:)
                               withObject:[NSNumber numberWithDouble:(double)((double)prog / (double)totalFlashRows)]
                            waitUntilDone:NO];

        NSString *msg2 = [NSString stringWithFormat:@"Upgrading firmware from file: %@\n", tmpFile];
        [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                withObject:msg2
                             waitUntilDone:YES];
        try
        {
            myBootloader->load(name, NULL);
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                    withObject: @"Firmware update successful\n"
                                 waitUntilDone:YES];
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                    withObject: [NSString stringWithFormat: @"Rows written: %d\n", totalFlashRows]
                                 waitUntilDone:YES];
        }
        catch (std::exception& e)
        {
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                   withObject: [NSString stringWithFormat:@"%s\n",e.what()]
                                waitUntilDone: YES];
            [self performSelectorOnMainThread: @selector(logStringToPanel:)
                                   withObject: @"Firmware update failed!\n"
                                waitUntilDone: YES];
        }
    }
    
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:100.0]
                        waitUntilDone:NO];
    
    [self performSelectorOnMainThread:@selector(startTimer)
                           withObject:NULL
                        waitUntilDone:NO];

}

@end
