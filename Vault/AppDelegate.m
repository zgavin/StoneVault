//
//  AppDelegate.m
//  Vault
//
//  Created by Zachary Gavin on 6/17/13.
//  Copyright (c) 2013 Zachary Gavin. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
	
	[@{@"appPath":@"/Applications/Timber and Stone OSX",@"pruneMinimumAge":@(2),@"pruneAgeDifference":@(2),@"pruneMinimumAgeUnit":@(86400),@"pruneAgeDifferenceUnit":@(3600)} enumerateKeysAndObjectsUsingBlock:^(NSString* key, id value, BOOL* stop) {
		if(![defaults objectForKey:key]) [defaults setObject:value forKey:key];
	}];
	
	if([defaults boolForKey:@"autoLaunch"] && !([NSEvent modifierFlags] & NSAlternateKeyMask) ) {
		[self launch];
	}
	
	[self validateAll];
}

- (IBAction) browsePressed:(id)sender {
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	openPanel.canChooseDirectories = YES;
	openPanel.canChooseFiles = NO;
	openPanel.directoryURL = [NSURL URLWithString:[@"file://localhost" stringByAppendingString:[pathTextField.stringValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	
	if(NSFileHandlingPanelOKButton == [openPanel runModal]) {
		pathTextField.stringValue = openPanel.URL.relativePath;
	}
}

- (BOOL) control:(NSControl *)control isValidObject:(id)obj {
	return control == pathTextField ? [[NSFileManager defaultManager] fileExistsAtPath:[(NSString*) obj stringByAppendingPathComponent:@"Timber and Stone.app"]] : control.stringValue.length > 0;
}

- (void)controlTextDidChange:(NSNotification *)notification {
	[self validateAll];
}

- (void) controlTextDidEndEditing:(NSNotification *)notification {
	[self validateAll];
}

- (void) validateAll {
	BOOL valid = YES;
	
	for(NSControl* control in @[pathTextField,pruneMinimumAgeTextField,pruneAgeDifferenceTextField]) {
		if(![self control:control isValidObject:control.stringValue]) {
			valid = NO;
		}
	}

	[launchButton setEnabled:valid];
}


- (IBAction) launchPressed:(id)sender {
	[self validateAll];
	if( !launchButton.isEnabled ) return;
	
	[NSUserDefaults.standardUserDefaults synchronize];
	
	[self launch];
}

- (void) launch {
	if([[NSWorkspace sharedWorkspace] launchApplication:[pathTextField.stringValue stringByAppendingPathComponent:@"Timber and Stone.app"]]) {
		[self.window close];
		[NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(workspaceApplicationTerminated:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
		[self backup];

    NSArray* pathsToWatch = @[[[pathTextField.stringValue stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:@"saves.sav"]];
		
		FSEventStreamContext context = {0, (__bridge void*) self, NULL, NULL, NULL};
		
    stream = FSEventStreamCreate(NULL, &saveFileChangedCallback, &context, (__bridge CFArrayRef) pathsToWatch, kFSEventStreamEventIdSinceNow, 1.0, kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagFileEvents );
		
		FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		
		FSEventStreamStart(stream);
	}
}

void saveFileChangedCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
	[(__bridge AppDelegate*) clientCallBackInfo performSelector:@selector(backup) withObject:nil afterDelay:4];
}

- (void) workspaceApplicationTerminated:(NSNotification*)notification {
	if([notification.userInfo[@"NSApplicationName"] isEqualToString:@"Timber and Stone"]) {
		[NSApplication.sharedApplication terminate:self];
	}
}

- (IBAction) backupPressed:(id)sender {
	[self backup];
}

- (void) backup {
	NSFileManager* fm = NSFileManager.defaultManager;
	
	NSString* savesFolderPath = [pathTextField.stringValue stringByAppendingPathComponent:@"saves"];

	NSError* error = nil;
	
	NSString* savesFile = [NSString stringWithContentsOfFile:[savesFolderPath stringByAppendingPathComponent:@"saves.sav"] encoding:NSUTF8StringEncoding error:&error];
	
	if(error) {
		NSLog(@"Unable to parse saves file");
		return;
	}
	
	NSArray* saveLines = [savesFile componentsSeparatedByString:@"\n"];
	
	NSString* allBackupsFolderPath = [pathTextField.stringValue stringByAppendingPathComponent:@"saves_backup"];
	
	if(![fm fileExistsAtPath:allBackupsFolderPath]) [fm createDirectoryAtPath:allBackupsFolderPath withIntermediateDirectories:NO attributes:nil error:&error];
	
	for(NSInteger i = 1; i < saveLines.count; i++) {
		
		NSString* save = [saveLines[i] componentsSeparatedByString:@"/"][0];
		if (save.length == 0) {
			continue;
		}
		
		NSString* savePath = [savesFolderPath stringByAppendingPathComponent:save];
		NSString* backupFolderPath = [allBackupsFolderPath stringByAppendingPathComponent:save];

    if(![fm fileExistsAtPath:backupFolderPath]) [fm createDirectoryAtPath:backupFolderPath withIntermediateDirectories:NO attributes:nil error:&error];
		
		NSDate* date = [fm attributesOfItemAtPath:savePath error:&error][NSFileModificationDate];
		
		NSDateFormatter* df = [[NSDateFormatter alloc] init];
		df.dateFormat = @"yyyy-MM-dd HH_mm_ss";
		
		NSString* backupName = [NSString stringWithFormat:@"%@ - %@.zip",save,[df stringFromDate:date]];
		NSString* backupPath = [backupFolderPath stringByAppendingPathComponent:backupName];
		
		if( ![fm fileExistsAtPath:backupPath] ) {
			NSLog(@"saving: %@",backupPath);
			
			NSTask *task;
			task = [[NSTask alloc] init];
			
			[task setLaunchPath:@"/usr/bin/zip"];
			
			task.currentDirectoryPath = savesFolderPath;
			
			[task setArguments: @[@"-r",backupPath,save]];
			
			NSPipe *pipe;
			pipe = [NSPipe pipe];
			[task setStandardOutput: pipe];
			[task setStandardError: pipe];
			
			NSFileHandle *file;
			file = [pipe fileHandleForReading];
			
			[task launch];
		}

		if( pruneButton.state == NSOnState ) {
			NSDate* lastDate;
			
			NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:@"^(.*) - (\\d\\d\\d\\d-\\d\\d-\\d\\d \\d\\d_\\d\\d_\\d\\d)\\.zip$" options:0 error:nil];
			
			for(NSString* current in [[fm contentsOfDirectoryAtPath:backupFolderPath error:nil] sortedArrayUsingSelector:@selector(localizedCompare:)])  {
				if( [current isEqualToString:backupName] ) continue;
				
				BOOL isDir;
				if( [fm fileExistsAtPath:[backupFolderPath stringByAppendingPathComponent:current] isDirectory:&isDir] && isDir ) continue;
				
				NSTextCheckingResult* match = [regexp firstMatchInString:current options:0	range:NSMakeRange(0, current.length)];

				if( !match || ![[current substringWithRange:[match rangeAtIndex:1]] isEqualToString:save] ) continue;
				
				date = [df dateFromString:[current substringWithRange:[match rangeAtIndex:2]]];
				
				if( ([NSDate timeIntervalSinceReferenceDate] - [date timeIntervalSinceReferenceDate]) < (pruneMinimumAgeTextField.integerValue * pruneMinimumAgeUnitPopUpButton.selectedTag) ) continue;
				
				if( !lastDate || [lastDate timeIntervalSinceReferenceDate] + (pruneAgeDifferenceTextField.integerValue * pruneAgeDifferenceUnitPopUpButton.selectedTag) < [date timeIntervalSinceReferenceDate]) {
					lastDate = date;
				} else {
					NSString* removePath = [backupFolderPath stringByAppendingPathComponent:current];
					NSLog(@"removing: %@",removePath);
					[fm removeItemAtPath:removePath error:nil];
				}
			}
		}
	}	
}

- (void) applicationWillTerminate:(NSNotification *)notification {
	[NSUserDefaults.standardUserDefaults synchronize];
	
	if(stream) {
		FSEventStreamStop(stream);
		FSEventStreamInvalidate(stream);
		FSEventStreamRelease(stream);
	}
}



@end
