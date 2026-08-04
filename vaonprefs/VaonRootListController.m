#include "VaonRootListController.h"

#if THEOS_PACKAGE_SCHEME_ROOTHIDE
#import <roothide.h>
#endif

//maybe check if the user is going back to the previous value a specifier was at before prompting the alert to repsring
//make a new NSUserDefauls
NSUserDefaults *prefs;
NSArray *rootPreferenceKeys;
NSArray *batteryPreferenceKeys;

//Function to check if an alias exists at a path
BOOL aliasExistsAtPath(NSString *path) {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error;
    BOOL isAlias = [url checkResourceIsReachableAndReturnError:&error];
    
    if (isAlias) {
        return YES;
    } else if (!isAlias && error.code == NSFileReadNoSuchFileError) {
        return NO;
    } else {
        NSLog(@"Error: %@", error);
        return NO;
    }
}

//respring by killing backboardd, resolving killall's path per jailbreak type
static void vaonRespring(void) {
	pid_t pid;
	const char *args[] = {"killall", "-9", "backboardd", NULL};
#if THEOS_PACKAGE_SCHEME_ROOTHIDE
	posix_spawn(&pid, jbroot("/usr/bin/killall"), NULL, NULL, (char *const *)args, NULL);
#else
	if (aliasExistsAtPath(@"/var/jb")) {
		posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
	} else {
		posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
	}
#endif
}

@implementation BatteryColorPreferenceController

	// -(id)init {
	// 	prefs = [[HBPreferences alloc] initWithIdentifier:@"com.atar13.vaonprefs"];
	// 	return [super init];
	// }

	-(NSArray *)specifiers {
		if (!_specifiers) {
			_specifiers = [self loadSpecifiersFromPlistName:@"BatteryColor" target:self];
		}

		return _specifiers;
	}
	-(void)viewDidLoad {
		[super viewDidLoad];
		self.title = @"Battery Color Settings";
	}
	-(void)respring {
		vaonRespring();
	}

	-(void)askBeforeRespring {
			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Are you sure you want to respring?" message:@"" preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
				[self respring];
			}];
			UIAlertAction* laterAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
			[alert addAction:respringAction];
			[alert addAction:laterAction];
			[self presentViewController:alert animated:YES completion:nil];
	}

    -(void)viewWillAppear:(BOOL)animated {
        [super viewWillAppear:animated];
        UIBarButtonItem *respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(askBeforeRespring)];
        self.navigationItem.rightBarButtonItem = respringButton; 
    }
	-(void)prefsChangeAlert {
			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Respring is required" message:@"To apply this change you must respring your device" preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
				[self respring];
			}];
			UIAlertAction* laterAction = [UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
			[alert addAction:respringAction];
			[alert addAction:laterAction];
			[self presentViewController:alert animated:YES completion:nil];
	}

	// -(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier{
	// 	[super setPreferenceValue:value specifier:specifier];
	// 	if((BOOL)specifier.properties[@"value"]==[prefs boolForKey:specifier.properties[@"key"]]){
	// 		if([batteryPreferenceKeys containsObject:specifier.properties[@"key"]]){
	// 			// [self prefsChangeAlert];
	// 		}
	// 	}
	// }


    

@end


@implementation BatteryPreferenceController

	// -(id)init {
	// 	prefs = [[HBPreferences alloc] initWithIdentifier:@"com.atar13.vaonprefs"];
	// 	return [super init];
	// }

	-(NSArray *)specifiers {
		if (!_specifiers) {
			_specifiers = [self loadSpecifiersFromPlistName:@"Battery" target:self];
		}

		return _specifiers;
	}
	-(void)viewDidLoad {
		[super viewDidLoad];
		self.title = @"Battery Configuration";
	}
	-(void)respring {
		vaonRespring();
	}

	-(void)askBeforeRespring {
			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Are you sure you want to respring?" message:@"" preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
				[self respring];
			}];
			UIAlertAction* laterAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
			[alert addAction:respringAction];
			[alert addAction:laterAction];
			[self presentViewController:alert animated:YES completion:nil];
	}

    -(void)viewWillAppear:(BOOL)animated {
        [super viewWillAppear:animated];
        UIBarButtonItem *respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(askBeforeRespring)];
        self.navigationItem.rightBarButtonItem = respringButton; 
    }
	-(void)prefsChangeAlert {
			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Respring is required" message:@"To apply this change you must respring your device" preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
				[self respring];
			}];
			UIAlertAction* laterAction = [UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
			[alert addAction:respringAction];
			[alert addAction:laterAction];
			[self presentViewController:alert animated:YES completion:nil];
	}

	-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier{
		[super setPreferenceValue:value specifier:specifier];
		if((BOOL)specifier.properties[@"value"]==[[prefs objectForKey:specifier.properties[@"key"]] boolValue]){
			if([batteryPreferenceKeys containsObject:specifier.properties[@"key"]]){
				// [self prefsChangeAlert];
			}
		}
	}


    

@end

@implementation VaonRootListController {
	//the pagination options that only make sense when page dots are shown; stashed so they can be
	//pulled out and re-inserted as the Show Page Dots switch flips
	NSArray *_swipeDependentSpecifiers;
	//the landscape offset controls, shown only while Vaon is not hidden in landscape
	NSArray *_landscapeOffsetSpecifiers;
}
	//-(id)readPreferenceValue:(PSSpecifier*)specifier; use this to get the current modele selected and make a method that returns it and passes it into the pslinkcell in root.plist
	-(id)init {
		prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
		rootPreferenceKeys = @[
			@"isEnabled",
			@"moduleSelection",
			@"hideBackground",
			@"enableFlyInOut",
			@"enableDelay",
			@"customHeightEnabled",
			@"customWidthEnabled",
			@"customVerticalOffsetEnabled"
		];
		batteryPreferenceKeys = @[
			@"hideInternal", 
			@"hidePercent", 
			@"enableBoldPercentage",
			@"roundOutlineCorners", 
			@"pulsateChargingOutline", 
			@"customBatteryCellSizeEnabled", 
			@"customPercentageFontSizeEnabled",
			@"roundOutlineCorners", 
			@"keepDisconnectedDevices"
		];
		return [super init];
	}

	-(NSArray *)specifiers {
		if (!_specifiers) {
			NSMutableArray *all = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
			//collect the dots-dependent options in plist order, then drop them if page dots are off
			NSMutableArray *deps = [NSMutableArray array];
			NSMutableArray *landDeps = [NSMutableArray array];
			for(PSSpecifier *s in all){
				NSString *sid = [s identifier];
				if([sid isEqualToString:@"verticalPageDots"] || [sid isEqualToString:@"pageDotsOnlyWhileSwiping"]){
					[deps addObject:s];
				}
				if([sid isEqualToString:@"landscapeOffsetEnabled"] || [sid isEqualToString:@"landscapeHOffsetHeader"] || [sid isEqualToString:@"landscapeHorizontalOffset"] || [sid isEqualToString:@"landscapeVOffsetHeader"] || [sid isEqualToString:@"landscapeVerticalOffset"]){
					[landDeps addObject:s];
				}
			}
			_swipeDependentSpecifiers = deps;
			_landscapeOffsetSpecifiers = landDeps;
			if(![[prefs objectForKey:@"showPageDots"] boolValue]){
				[all removeObjectsInArray:deps];
			}
			//the landscape offset controls only apply when Vaon is not hidden in landscape
			if([[prefs objectForKey:@"hideInLandscape"] boolValue]){
				[all removeObjectsInArray:landDeps];
			}
			_specifiers = all;
		}

		return _specifiers;
	}

	//insert or remove the dots-dependent options right after Show Page Dots as it toggles
	-(void)setPageDotDependentsVisible:(BOOL)visible {
		if(_swipeDependentSpecifiers.count == 0) return;
		BOOL currentlyShown = ([self indexOfSpecifier:_swipeDependentSpecifiers.firstObject] != NSNotFound);
		if(visible && !currentlyShown){
			PSSpecifier *anchor = [self specifierForID:@"showPageDots"];
			if(anchor) [self insertContiguousSpecifiers:_swipeDependentSpecifiers afterSpecifier:anchor animated:YES];
		} else if(!visible && currentlyShown){
			[self removeContiguousSpecifiers:_swipeDependentSpecifiers animated:YES];
		}
	}

	//show the landscape offset controls only while Vaon is not hidden in landscape
	-(void)setLandscapeOffsetDependentsVisible:(BOOL)visible {
		if(_landscapeOffsetSpecifiers.count == 0) return;
		BOOL currentlyShown = ([self indexOfSpecifier:_landscapeOffsetSpecifiers.firstObject] != NSNotFound);
		if(visible && !currentlyShown){
			PSSpecifier *anchor = [self specifierForID:@"hideInLandscape"];
			if(anchor) [self insertContiguousSpecifiers:_landscapeOffsetSpecifiers afterSpecifier:anchor animated:YES];
		} else if(!visible && currentlyShown){
			[self removeContiguousSpecifiers:_landscapeOffsetSpecifiers animated:YES];
		}
	}

	-(void)respring {
		vaonRespring();
	}
	-(void)askBeforeRespring {
		UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Are you sure you want to respring?" message:@"" preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
			[self respring];
		}];
		UIAlertAction* laterAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
		[alert addAction:respringAction];
		[alert addAction:laterAction];
		[self presentViewController:alert animated:YES completion:nil];
	}

	//methods for links to social media/github
	-(void)reddit {
		[[UIApplication sharedApplication] 
			openURL:[NSURL URLWithString:@"https://reddit.com/u/atar13"] 
			options:@{} 
		completionHandler:nil];
	}

	- (void)twitter {
		[[UIApplication sharedApplication] 
			openURL:[NSURL URLWithString:@"https://twitter.com/atar137h"] 
			options:@{} 
		completionHandler:nil];
	}

	- (void)twitterKeycap {
		[[UIApplication sharedApplication] 
			openURL:[NSURL URLWithString:@"https://twitter.com/singlekeycap"] 
			options:@{} 
		completionHandler:nil];
	}

	-(void)email{
		[[UIApplication sharedApplication] 
			openURL:[NSURL URLWithString:@"mailto:atar13dev@gmail.com"] 
			options:@{} 
		completionHandler:nil];
	}

	-(void)github{
		[[UIApplication sharedApplication] 
			openURL:[NSURL URLWithString:@"https://github.com/atar13/Vaon"] 
			options:@{} 
		completionHandler:nil];
	}

	-(void)report{
		[[UIApplication sharedApplication]
			openURL:[NSURL URLWithString:@"https://github.com/atar13/Vaon/issues/new"]
			options:@{}
		completionHandler:nil];
	}

	-(void)githubCySxL{
		[[UIApplication sharedApplication]
			openURL:[NSURL URLWithString:@"https://github.com/CySxL"]
			options:@{}
		completionHandler:nil];
	}

	- (void)viewWillAppear:(BOOL)animated {
		[super viewWillAppear:animated];
		UIBarButtonItem *respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(askBeforeRespring)];
		self.navigationItem.rightBarButtonItem = respringButton; 
	}

	-(void)prefsChangeAlert {
			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Respring is required" message:@"To apply this change you must respring your device" preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
				[self respring];
			}];
			UIAlertAction* laterAction = [UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
			[alert addAction:respringAction];
			[alert addAction:laterAction];
			[self presentViewController:alert animated:YES completion:nil];
	}
	-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier{
		[super setPreferenceValue:value specifier:specifier];
		if([specifier.properties[@"key"] isEqualToString:@"showPageDots"]){
			[self setPageDotDependentsVisible:[value boolValue]];
		}
		if([specifier.properties[@"key"] isEqualToString:@"hideInLandscape"]){
			[self setLandscapeOffsetDependentsVisible:![value boolValue]];
		}
		if([rootPreferenceKeys containsObject:specifier.properties[@"key"]]){

			if([specifier.properties[@"cell"] isEqual:@"PSSwitchCell"]){
				if(!(BOOL)specifier.properties[@"value"]==[[prefs objectForKey:specifier.properties[@"key"]] boolValue]){
						// [self prefsChangeAlert];
				}
			}
			else {
				[self prefsChangeAlert];
			}
		}
	}



@end


@implementation VaonPinnedDevicesController {
	NSMutableArray *_knownDevices;
	NSMutableArray *_pinnedIds;
	UITableView *_tableView;
}

	-(NSUserDefaults *)store {
		return [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
	}

	-(void)loadModel {
		NSUserDefaults *d = [self store];
		NSArray *raw = [d objectForKey:@"knownDevices"] ?: @[];
		//one row per name (AirPods report left/right under the same name); map every id to its representative
		NSMutableArray *collapsed = [NSMutableArray array];
		NSMutableDictionary *nameToRep = [NSMutableDictionary dictionary];
		NSMutableDictionary *idToRep = [NSMutableDictionary dictionary];
		for(NSDictionary *dev in raw){
			NSString *nm = dev[@"name"];
			NSString *ident = dev[@"identifier"];
			if(!ident) continue;
			NSString *rep = nm.length ? nameToRep[nm] : nil;
			if(rep == nil){
				rep = ident;
				if(nm.length) nameToRep[nm] = ident;
				[collapsed addObject:dev];
			}
			idToRep[ident] = rep;
		}
		_knownDevices = collapsed;
		NSArray *rawPinned = [d arrayForKey:@"pinnedDeviceIdentifiers"] ?: @[];
		_pinnedIds = [NSMutableArray array];
		for(NSString *pid in rawPinned){
			NSString *rep = idToRep[pid];
			if(rep && ![_pinnedIds containsObject:rep]) [_pinnedIds addObject:rep];
		}
	}

	-(void)saveModel {
		NSUserDefaults *d = [self store];
		[d setObject:_pinnedIds forKey:@"pinnedDeviceIdentifiers"];
		[d synchronize];
	}

	-(void)viewDidLoad {
		[super viewDidLoad];
		self.title = @"Pinned Devices";
		[self loadModel];
		_tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
		_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_tableView.dataSource = self;
		_tableView.delegate = self;
		_tableView.allowsSelectionDuringEditing = YES;
		[_tableView setEditing:YES animated:NO];
		[self.view addSubview:_tableView];
	}

	-(void)viewDidLayoutSubviews {
		[super viewDidLayoutSubviews];
		_tableView.frame = self.view.bounds;
	}

	-(void)viewWillAppear:(BOOL)animated {
		[super viewWillAppear:animated];
		[self loadModel];
		[_tableView setEditing:YES animated:NO];
		[_tableView reloadData];
	}

	-(NSDictionary *)recordForId:(NSString *)pid {
		for(NSDictionary *dev in _knownDevices){ if([dev[@"identifier"] isEqualToString:pid]) return dev; }
		return nil;
	}

	-(NSArray *)availableDevices {
		NSMutableArray *a = [NSMutableArray array];
		for(NSDictionary *dev in _knownDevices){ if(![_pinnedIds containsObject:dev[@"identifier"]]) [a addObject:dev]; }
		return a;
	}

	-(NSDictionary *)deviceAtIndexPath:(NSIndexPath *)ip {
		if(_knownDevices.count == 0) return nil;
		if(ip.section == 0){
			if(ip.row >= (NSInteger)_pinnedIds.count) return nil;
			return [self recordForId:_pinnedIds[ip.row]];
		}
		NSArray *avail = [self availableDevices];
		if(ip.row >= (NSInteger)avail.count) return nil;
		return avail[ip.row];
	}

	-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

	-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
		if(_knownDevices.count == 0) return (section == 0) ? 1 : 0;
		return (section == 0) ? _pinnedIds.count : [self availableDevices].count;
	}

	-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
		return (section == 0) ? @"Pinned (drag to reorder)" : @"Available Devices";
	}

	-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
		return (section == 1) ? @"Pinned devices stay shown after respring, even when disconnected. Respring to apply." : nil;
	}

	-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"vaonDeviceCell"];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		if(_knownDevices.count == 0){
			cell.textLabel.text = @"No devices seen yet";
			cell.detailTextLabel.text = @"Connect a Bluetooth device once, then come back.";
			return cell;
		}
		NSDictionary *dev = [self deviceAtIndexPath:indexPath];
		cell.textLabel.text = dev[@"name"] ?: dev[@"identifier"];
		long long last = [dev[@"lastPercentage"] longLongValue];
		cell.detailTextLabel.text = (last < 0) ? @"No battery reporting" : [NSString stringWithFormat:@"%lld%%", last];
		NSString *customSym = dev[@"customGlyph"];
		if([customSym isKindOfClass:[NSString class]] && customSym.length){
			cell.imageView.image = [[UIImage systemImageNamed:customSym] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
			cell.imageView.tintColor = [UIColor labelColor];
		} else {
			NSData *g = dev[@"glyph"];
			UIImage *img = [g isKindOfClass:[NSData class]] ? [UIImage imageWithData:g] : nil;
			//Bluetooth-sourced records carry no battery widget glyph, so show the same generic one the
			//switcher uses; without an image the icon has no frame and cannot be tapped to pick a symbol
			if(!img) img = [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
			cell.imageView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
			cell.imageView.tintColor = [UIColor labelColor];
		}
		cell.imageView.userInteractionEnabled = YES;
		[cell.imageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(glyphTapped:)]];
		UISwitch *sw = [[UISwitch alloc] init];
		sw.on = (indexPath.section == 0);
		[sw addTarget:self action:@selector(pinSwitchChanged:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = sw;
		cell.editingAccessoryView = sw;
		cell.showsReorderControl = (indexPath.section == 0);
		return cell;
	}

	-(void)pinSwitchChanged:(UISwitch *)sw {
		UIView *v = sw;
		while(v && ![v isKindOfClass:[UITableViewCell class]]) v = v.superview;
		if(!v) return;
		NSIndexPath *ip = [_tableView indexPathForCell:(UITableViewCell *)v];
		NSDictionary *dev = [self deviceAtIndexPath:ip];
		NSString *identifier = dev[@"identifier"];
		if(!identifier) return;
		if(sw.on){
			if(![_pinnedIds containsObject:identifier]) [_pinnedIds addObject:identifier];
		} else {
			[_pinnedIds removeObject:identifier];
		}
		[self saveModel];
		[_tableView reloadData];
	}

	-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
		//available devices can be deleted from the store to declutter; pinned rows only reorder
		return (indexPath.section == 1 && _knownDevices.count > 0) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
	}

	-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
		//both sections must be editable so section 0 shows the reorder control; editingStyle differentiates
		return (_knownDevices.count > 0);
	}

	-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
		if(editingStyle != UITableViewCellEditingStyleDelete) return;
		NSDictionary *dev = [self deviceAtIndexPath:indexPath];
		NSString *ident = dev[@"identifier"];
		NSString *nm = dev[@"name"];
		if(!ident) return;
		NSUserDefaults *d = [self store];
		//remove every stored record sharing this name (or identifier), plus any pins referencing them
		NSArray *raw = [d objectForKey:@"knownDevices"] ?: @[];
		NSMutableArray *keptDevices = [NSMutableArray array];
		NSMutableSet *removedIds = [NSMutableSet set];
		for(NSDictionary *r in raw){
			BOOL match = [r[@"identifier"] isEqualToString:ident] || (nm.length && [r[@"name"] isEqualToString:nm]);
			if(match){ if(r[@"identifier"]) [removedIds addObject:r[@"identifier"]]; }
			else { [keptDevices addObject:r]; }
		}
		[d setObject:keptDevices forKey:@"knownDevices"];
		NSArray *rawPinned = [d arrayForKey:@"pinnedDeviceIdentifiers"] ?: @[];
		NSMutableArray *keptPins = [NSMutableArray array];
		for(NSString *pid in rawPinned){ if(![removedIds containsObject:pid]) [keptPins addObject:pid]; }
		[d setObject:keptPins forKey:@"pinnedDeviceIdentifiers"];
		[d synchronize];
		[self loadModel];
		[_tableView reloadData];
	}

	-(BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath { return NO; }

	-(BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
		return (indexPath.section == 0 && _pinnedIds.count > 1);
	}

	-(NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)prop {
		if(prop.section != 0) return [NSIndexPath indexPathForRow:(_pinnedIds.count > 0 ? _pinnedIds.count - 1 : 0) inSection:0];
		return prop;
	}

	-(void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)dest {
		if(source.section != 0 || dest.section != 0) return;
		NSString *moved = _pinnedIds[source.row];
		[_pinnedIds removeObjectAtIndex:source.row];
		[_pinnedIds insertObject:moved atIndex:dest.row];
		[self saveModel];
	}

	-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	}

	//only tapping the glyph icon opens the picker, not the whole row (avoids reorder/delete mis-triggers)
	-(void)glyphTapped:(UITapGestureRecognizer *)gesture {
		UIView *v = gesture.view;
		while(v && ![v isKindOfClass:[UITableViewCell class]]) v = v.superview;
		if(!v) return;
		NSIndexPath *ip = [_tableView indexPathForCell:(UITableViewCell *)v];
		NSDictionary *dev = [self deviceAtIndexPath:ip];
		if(!dev) return;
		VaonGlyphPickerController *picker = [[VaonGlyphPickerController alloc] init];
		picker.targetDeviceName = dev[@"name"];
		picker.targetDeviceIdentifier = dev[@"identifier"];
		[self.navigationController pushViewController:picker animated:YES];
	}

@end


@implementation VaonGlyphPickerController {
	NSArray *_symbols;
	UITableView *_tableView;
}

	-(NSUserDefaults *)store {
		return [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
	}

	-(void)viewDidLoad {
		[super viewDidLoad];
		self.title = @"Choose Glyph";
		//curated SF Symbols relevant to bluetooth accessories. first entry = reset to default.
		//every name here ships in iOS 16.0 or earlier, so none of them resolve to nil on device
		_symbols = @[
			@"",
			//earbuds
			@"airpods", @"airpodspro", @"airpodsmax", @"airpods.gen3", @"earpods", @"earbuds",
			@"airpod.left", @"airpod.right", @"airpodpro.left", @"airpodpro.right",
			@"airpod.gen3.left", @"airpod.gen3.right",
			@"airpods.chargingcase.wireless.fill", @"airpodspro.chargingcase.wireless.fill",
			@"airpods.gen3.chargingcase.wireless.fill",
			//headphones
			@"headphones", @"headphones.circle", @"headphones.circle.fill",
			@"beats.headphones", @"beats.earphones", @"beats.studiobuds",
			@"beats.studiobud.left", @"beats.studiobud.right",
			@"beats.powerbeats", @"beats.powerbeatspro", @"beats.fit.pro",
			@"hearingdevice.ear", @"ear.and.waveform",
			//speakers
			@"hifispeaker.fill", @"hifispeaker.2.fill", @"homepod.fill", @"homepod.2.fill",
			@"homepodmini.fill", @"hifispeaker.and.homepod.fill", @"tv.and.hifispeaker.fill",
			@"speaker.fill", @"speaker.wave.1.fill", @"speaker.wave.2.fill", @"speaker.wave.3.fill",
			@"music.note", @"music.mic", @"waveform", @"waveform.circle.fill",
			//tv, airplay and remotes
			@"appletv.fill", @"tv.fill", @"airplayaudio", @"airplayvideo", @"av.remote",
			@"appletvremote.gen4.fill",
			//car
			@"car.fill", @"car.2.fill", @"bolt.car.fill",
			//input devices and computers
			@"keyboard", @"keyboard.fill", @"magicmouse.fill", @"computermouse.fill",
			@"applepencil", @"gamecontroller.fill", @"laptopcomputer", @"desktopcomputer",
			//apple devices
			@"iphone", @"ipad", @"applewatch", @"ipodtouch",
			//generic wireless
			@"antenna.radiowaves.left.and.right", @"dot.radiowaves.left.and.right",
			@"dot.radiowaves.forward", @"wave.3.right", @"airtag.radiowaves.forward.fill",
			@"sensor.tag.radiowaves.forward.fill", @"printer.fill"
		];
		_tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
		_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_tableView.dataSource = self;
		_tableView.delegate = self;
		[self.view addSubview:_tableView];
	}

	-(void)viewDidLayoutSubviews {
		[super viewDidLayoutSubviews];
		_tableView.frame = self.view.bounds;
	}

	-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
		return _symbols.count;
	}

	-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
		return self.targetDeviceName;
	}

	-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
		return @"Tap a symbol to use it for this device. Respring to apply.";
	}

	-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sym"];
		NSString *sym = _symbols[indexPath.row];
		if(sym.length == 0){
			cell.textLabel.text = @"Default (device icon)";
			cell.imageView.image = nil;
		} else {
			cell.textLabel.text = sym;
			cell.imageView.image = [[UIImage systemImageNamed:sym] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
			cell.imageView.tintColor = [UIColor labelColor];
		}
		NSString *current = [self currentSymbol];
		BOOL selected = (sym.length == 0) ? (current.length == 0) : [current isEqualToString:sym];
		cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
		return cell;
	}

	-(NSString *)currentSymbol {
		NSArray *known = [[self store] objectForKey:@"knownDevices"] ?: @[];
		for(NSDictionary *d in known){
			if(self.targetDeviceName.length && [d[@"name"] isEqualToString:self.targetDeviceName]){
				NSString *s = d[@"customGlyph"];
				if([s isKindOfClass:[NSString class]]) return s;
			}
		}
		return @"";
	}

	-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		NSString *sym = _symbols[indexPath.row];
		NSUserDefaults *d = [self store];
		NSArray *raw = [d objectForKey:@"knownDevices"] ?: @[];
		NSMutableArray *updated = [NSMutableArray array];
		for(NSDictionary *r in raw){
			BOOL match = (self.targetDeviceName.length && [r[@"name"] isEqualToString:self.targetDeviceName])
				|| [r[@"identifier"] isEqualToString:self.targetDeviceIdentifier];
			if(match){
				NSMutableDictionary *m = [r mutableCopy];
				if(sym.length) m[@"customGlyph"] = sym; else [m removeObjectForKey:@"customGlyph"];
				[updated addObject:m];
			} else {
				[updated addObject:r];
			}
		}
		[d setObject:updated forKey:@"knownDevices"];
		[d synchronize];
		[_tableView reloadData];
	}

@end


@implementation ImageCell

	-(id)initWithSpecifier:(PSSpecifier *)specifier {
		self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell" specifier:specifier];
		if(self){
		CGRect frame = CGRectMake(0, 2, [[UIScreen mainScreen] bounds].size.width, 60);

        NSString *customImagePath = [[NSBundle bundleForClass:[self class]].bundlePath stringByAppendingPathComponent:@"images/email/emailIcon@3x.png"];
		image = [[UIImage alloc] initWithContentsOfFile:customImagePath];
		if(image == nil){
			UILabel *label = [[UILabel alloc] initWithFrame:frame];
			NSString *labelText = @"Image didn't load";
			label.text = labelText;
			[self addSubview:label];
		} else {
			imageView = [[UIImageView alloc] initWithImage:image];
			imageView.contentMode = UIViewContentModeScaleAspectFit;
			
			[self addSubview:imageView];
		}
		}
		return self;
	}

	- (CGFloat)preferredHeightForWidth:(CGFloat)width {
	// Return a custom cell height.
		return 100.f;
	}
@end


@implementation VaonStepperCell

	//integer +/- stepper so the per-page count can never land on a fraction
	-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
		self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier specifier:specifier];
		if(self){
			self.selectionStyle = UITableViewCellSelectionStyleNone;
			self.textLabel.text = [specifier name];
			NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
			double minV = [specifier.properties[@"min"] doubleValue];
			double maxV = [specifier.properties[@"max"] doubleValue];
			id cur = [d objectForKey:specifier.properties[@"key"]];
			double val = cur ? [cur doubleValue] : [specifier.properties[@"default"] doubleValue];
			if(val < minV) val = minV;
			if(val > maxV) val = maxV;
			_valueLabel = [[UILabel alloc] init];
			_valueLabel.textColor = [UIColor secondaryLabelColor];
			_valueLabel.text = [NSString stringWithFormat:@"%d", (int)val];
			[_valueLabel sizeToFit];
			_stepper = [[UIStepper alloc] init];
			_stepper.minimumValue = minV;
			_stepper.maximumValue = maxV;
			_stepper.stepValue = 1;
			_stepper.value = val;
			[_stepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
			[_stepper sizeToFit];
			CGFloat gap = 10;
			UIView *acc = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _valueLabel.frame.size.width + gap + _stepper.frame.size.width, _stepper.frame.size.height)];
			_valueLabel.frame = CGRectMake(0, (_stepper.frame.size.height - _valueLabel.frame.size.height) / 2.0, _valueLabel.frame.size.width, _valueLabel.frame.size.height);
			_stepper.frame = CGRectMake(_valueLabel.frame.size.width + gap, 0, _stepper.frame.size.width, _stepper.frame.size.height);
			[acc addSubview:_valueLabel];
			[acc addSubview:_stepper];
			self.accessoryView = acc;
		}
		return self;
	}

	-(void)stepperChanged:(UIStepper *)stepper {
		int v = (int)stepper.value;
		_valueLabel.text = [NSString stringWithFormat:@"%d", v];
		NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
		[d setObject:@(v) forKey:self.specifier.properties[@"key"]];
		[d synchronize];
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.atar13.vaonprefs/prefschanged"), NULL, NULL, YES);
	}

@end