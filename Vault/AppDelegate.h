//
//  AppDelegate.h
//  Vault
//
//  Created by Zachary Gavin on 6/17/13.
//  Copyright (c) 2013 Zachary Gavin. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate,NSTextFieldDelegate> {
	IBOutlet NSTextField* pathTextField;
	
	IBOutlet NSButton* launchButton;
	
	IBOutlet NSButton* autolaunchButton;
	IBOutlet NSButton* pruneButton;
	
	IBOutlet NSTextField* pruneMinimumAgeTextField;
	IBOutlet NSTextField* pruneAgeDifferenceTextField;
	
	IBOutlet NSPopUpButton* pruneMinimumAgeUnitPopUpButton;
	IBOutlet NSPopUpButton* pruneAgeDifferenceUnitPopUpButton;
	
	FSEventStreamRef stream;
}

@property (assign) IBOutlet NSWindow *window;

@end
