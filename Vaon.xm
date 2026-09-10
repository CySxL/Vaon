//credit to Dogbert for the icon

#import "Vaon.h"
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <dlfcn.h>
// #import <Foundation/Foundation.h>


NSUserDefaults *prefs;

//main page preference variables
BOOL isEnabled;
NSString *selectedModule = nil;
BOOL hideBackground;

NSString *backgroundMode = nil;

BOOL enableFlyInOut;
BOOL enableDelay;
CGFloat fadeInDelay;

BOOL customHeightEnabled;
CGFloat customHeight;
BOOL customWidthEnabled;
CGFloat customWidth;
BOOL customVerticalOffsetEnabled;
CGFloat customVerticalOffset;
BOOL customHorizontalOffsetEnabled;
CGFloat customHorizontalOffset;


//battery configuration preference variables
BOOL hideInternal;
BOOL hidePercentageLabel;
BOOL hidePercent;
BOOL enableBoldPercentage;
BOOL roundOutlineCorners;
BOOL pulsateChargingOutline;
BOOL keepDisconnectedDevices;
NSString *batteryTextColor = nil;
NSString *customBatteryTextColor = nil;
NSString *batteryGlyphBackgroundMode = nil;
BOOL customDeviceGlyphSizeEnabled;
CGFloat customDeviceGlyphSize;
BOOL customBatteryCellSizeEnabled;
CGFloat customBatteryCellSize; 
BOOL customPercentageFontSizeEnabled;
CGFloat customPercentageFontSize;
BOOL paddingBetweenGlyphAndLabelEnabled;
CGFloat paddingBetweenGlyphAndLabel;
BOOL horizontalSpacingBetweenDevicesEnabled;
CGFloat horizontalSpacingBetweenDevices;

UIView *vaonView;

UIScrollView *batteryScrollView;

UIStackView *batteryHStackView;

//pagination
NSInteger devicesPerPage;
BOOL showPageDots;
BOOL pageDotsOnlyWhileSwiping;
BOOL verticalPageDots;
BOOL rememberLastPage;
UIPageControl *batteryPageControl;
NSInteger currentBatteryPage;
id vaonScrollDelegate;

UIVisualEffectView *vaonBlurView;
UIBlurEffect *blurEffect;

int vaonViewCornerRadius = 17;

CGFloat dockWidth;
BOOL vaonViewIsInitialized = FALSE;

//landscape handling
BOOL hideInLandscape;
BOOL landscapeOffsetEnabled;
CGFloat landscapeHorizontalOffset;
CGFloat landscapeVerticalOffset;
NSLayoutConstraint *vaonBottomConstraint;
NSLayoutConstraint *vaonCenterXConstraint;
CGFloat vaonViewHeightCaptured;

//defined lower down but used by the fade helpers above them
static BOOL vaonIsLandscape(UIView *view);
static void vaonApplyOrientationLayout(UIView *host);

SBSwitcherAppSuggestionContentView *switcherContentView;
//frontmost app bundle id captured when the switcher opened; used to tell a cancelled leave (same
//front app, switcher stays) from an app launch or going home (front app changes)
NSString *vaonOpenFrontApp;
BOOL stockHidden = TRUE;
//set at fade-in completion, cleared at fade-out start; stockHidden is unreliable on iOS 16
BOOL vaonShown = FALSE;

NSArray *connectedBluetoothDevices;
NSArray *connectedBluetoothAccessories;

UIColor *normalBatteryColor = [UIColor colorWithRed:0.1882352941 green:0.8196078431 blue:0.3450980392 alpha: 1];
UIColor *lowPowerModeColor = [UIColor colorWithRed:1 green:0.8 blue:0 alpha:1];
UIColor *lowBatteryColor = [UIColor redColor];
UIColor *darkGrayColor = [UIColor colorWithRed:0.1746478873 green:0.2039215686 blue:0.1960784314 alpha: 1];

//timers to initiate animations
NSTimer *delayedFadeInTimer = nil;


BOOL firstSlideIn = false;

NSString *customConnectedDeviceColorMode;
NSString *customConnectedDeviceColor;

NSString *customDisconnectedDeviceColorMode;
NSString *customDisconnectedDeviceColor;

NSString *customLowPowerColorMode;
NSString *customLowPowerColor;

NSString *customLowBatteryColorMode;
NSString *customLowBatteryColor;

NSString *customChargingColorMode;
NSString *customChargingColor;

NSString *customNoBatteryConnectedColorMode;
NSString *customNoBatteryConnectedColor;

NSString *customNoBatteryDisconnectedColorMode;
NSString *customNoBatteryDisconnectedColor;

UIColor* colorFromHexString(NSString *hexString) {
    if(![hexString isKindOfClass:[NSString class]] || hexString.length == 0) return [UIColor clearColor];
    NSString *digits = [hexString hasPrefix:@"#"] ? [hexString substringFromIndex:1] : hexString;
    unsigned long long value = 0;
    if(![[NSScanner scannerWithString:digits] scanHexLongLong:&value]) return [UIColor clearColor];
    //the pickers offer an alpha slider, and Alderis writes AARRGGBB once alpha leaves full. the
    //low 24 bits are RRGGBB either way, so the shifts below are the same for 6 and 8 digits
    CGFloat alpha = 1.0;
    if(digits.length >= 8) alpha = ((value >> 24) & 0xFF)/255.0;
    return [UIColor colorWithRed:((value & 0xFF0000) >> 16)/255.0 green:((value & 0xFF00) >> 8)/255.0 blue:(value & 0xFF)/255.0 alpha:alpha];
}

//how far the drawn ink of a string sits above its baseline, at its midpoint. lets glyphs of different
//sizes be lined up on what the eye reads as their centre rather than on font metrics
static CGFloat vaonInkCenterAboveBaseline(NSString *text, UIFont *font) {
	CTFontRef ctFont = (__bridge CTFontRef)font;
	NSUInteger count = text.length;
	if(count == 0 || count > 8) return font.capHeight / 2;
	UniChar characters[8];
	CGGlyph glyphs[8];
	[text getCharacters:characters range:NSMakeRange(0, count)];
	if(!CTFontGetGlyphsForCharacters(ctFont, characters, glyphs, count)) return font.capHeight / 2;
	CGRect ink = CTFontGetBoundingRectsForGlyphs(ctFont, kCTFontOrientationHorizontal, glyphs, NULL, count);
	if(CGRectIsNull(ink) || CGRectIsEmpty(ink)) return font.capHeight / 2;
	return CGRectGetMidY(ink);
}

//where a single line of this font puts its baseline inside a label of the given height
static CGFloat vaonBaselineInLabel(UIFont *font, CGFloat labelHeight) {
	return (labelHeight - font.lineHeight) / 2 + font.ascender;
}

//how far to lift the infinity sign so its centre line meets the digits beside it. the fonts come from
//prefs read once at load, so this only ever needs measuring once
static CGFloat vaonInfinitySignNudge(UIFont *base, UIFont *large, CGFloat labelHeight) {
	static CGFloat nudge;
	static BOOL measured = FALSE;
	if(!measured){
		CGFloat digitCentre = vaonBaselineInLabel(base, labelHeight) - vaonInkCenterAboveBaseline(@"0", base);
		CGFloat signCentre = vaonBaselineInLabel(large, labelHeight) - vaonInkCenterAboveBaseline(@"∞", large);
		nudge = digitCentre - signCentre;
		measured = TRUE;
	}
	return nudge;
}

//whole days since the epoch. the store only needs to know how long ago a device was last seen, and a
//day granularity keeps an unchanged device to one write a day instead of one a pass
static long long vaonToday(void) {
	return (long long)([[NSDate date] timeIntervalSince1970] / 86400.0);
}

//knownDevices was read back from prefs for every device on every switcher open, and rewritten whole
//each time a percentage moved. the records carry glyph PNGs, so hold the list for the pass instead:
//reloaded when the pass starts, so changes made in the prefs app are still picked up, written once
static NSMutableArray *vaonKnownDevices;
static BOOL vaonKnownDevicesDirty;

//BatteryCenter hands out a different identifier for the same accessory depending on how its parts were
//enumerated: AirPods come back as their ear pieces concatenated in whatever order that time, and the
//internal battery and MagSafe pack get a fresh number every connection. Left alone the store grows one
//record per variation, each carrying its own glyph PNG. MAC based ids key on their unique parts sorted,
//which keeps genuinely separate units apart; the rest can only be keyed on the name
static NSString *vaonDeviceKey(NSString *identifier, NSString *name) {
	//also called with names and identifiers straight off BatteryCenter and BluetoothManager, which
	//the store's normalisation says nothing about
	if(![identifier isKindOfClass:[NSString class]]) identifier = nil;
	if(![name isKindOfClass:[NSString class]]) name = nil;
	if([identifier containsString:@":"]){
		NSArray *parts = [[NSSet setWithArray:[identifier componentsSeparatedByString:@"-"]] allObjects];
		return [[parts sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"-"];
	}
	return [@"name:" stringByAppendingString:(name ?: identifier ?: @"")];
}

//pins come out of the same user writable plist as the records, and they end up as isEqualToString:
//arguments, so anything that is not a string is dropped here rather than at each use
static NSArray *vaonPinnedIdentifiers() {
	NSMutableArray *pins = [NSMutableArray array];
	for(id pid in [prefs arrayForKey:@"pinnedDeviceIdentifiers"]){
		if([pid isKindOfClass:[NSString class]]) [pins addObject:pid];
	}
	return pins;
}

//fold the historical duplicates into one record each. the pinned identifier wins so existing pins keep
//resolving, and a glyph is carried over from whichever copy has one
static void vaonCompactKnownDevices(NSMutableArray *devices) {
	NSArray *pinned = vaonPinnedIdentifiers();
	NSMutableDictionary *byKey = [NSMutableDictionary dictionary];
	NSMutableArray *order = [NSMutableArray array];
	for(NSDictionary *record in devices){
		NSString *key = vaonDeviceKey(record[@"identifier"], record[@"name"]);
		NSMutableDictionary *winner = byKey[key];
		if(!winner){
			byKey[key] = [record mutableCopy];
			[order addObject:key];
			continue;
		}
		if([pinned containsObject:record[@"identifier"]] && ![pinned containsObject:winner[@"identifier"]]){
			NSMutableDictionary *replacement = [record mutableCopy];
			if(!replacement[@"glyph"] && winner[@"glyph"]) replacement[@"glyph"] = winner[@"glyph"];
			if(!replacement[@"customGlyph"] && winner[@"customGlyph"]) replacement[@"customGlyph"] = winner[@"customGlyph"];
			byKey[key] = replacement;
		} else {
			if(!winner[@"glyph"] && record[@"glyph"]) winner[@"glyph"] = record[@"glyph"];
			if(!winner[@"customGlyph"] && record[@"customGlyph"]) winner[@"customGlyph"] = record[@"customGlyph"];
		}
	}
	if(byKey.count == devices.count) return;
	[devices removeAllObjects];
	for(NSString *key in order) [devices addObject:byKey[key]];
	vaonKnownDevicesDirty = TRUE;
}

//nothing in the store is guaranteed to have the type it was written with, so the whole list is
//normalised on load and every reader below can take the fields at face value. a record without an
//identifier string is dropped: it can neither be matched nor pinned, and the upsert refuses to write one
static NSMutableArray *vaonNormalizeKnownDevices(id stored, BOOL *changed) {
	NSMutableArray *devices = [NSMutableArray array];
	if(![stored isKindOfClass:[NSArray class]]){
		if(stored) *changed = TRUE;
		return devices;
	}
	for(id entry in (NSArray *)stored){
		if(![entry isKindOfClass:[NSDictionary class]]){ *changed = TRUE; continue; }
		NSDictionary *raw = entry;
		NSMutableDictionary *record = [NSMutableDictionary dictionary];
		for(NSString *field in @[@"identifier", @"name", @"source", @"customGlyph"]){
			if([raw[field] isKindOfClass:[NSString class]]) record[field] = raw[field];
		}
		for(NSString *field in @[@"productIdentifier", @"lastPercentage", @"lastSeen"]){
			if([raw[field] isKindOfClass:[NSNumber class]]) record[field] = raw[field];
		}
		if([raw[@"glyph"] isKindOfClass:[NSData class]]) record[@"glyph"] = raw[@"glyph"];
		if(record.count != raw.count) *changed = TRUE;
		if(!record[@"identifier"]) continue;
		//a record stored before 1.9.10 has no date. stamp it as seen now rather than expiring it, so the
		//window starts here for everything already in the store and nothing is dropped on this pass
		if(!record[@"lastSeen"]){
			record[@"lastSeen"] = @(vaonToday());
			*changed = TRUE;
		}
		[devices addObject:record];
	}
	return devices;
}

//an accessory that stopped connecting keeps its record, and with it a MAC based identifier and the
//name it was sold under, for as long as the store lives. drop one that has not been seen for this long.
//pinned records are never candidates, and neither is anything connected: the pass stamps every device
//it gathers before this runs
#define VAON_KNOWN_DEVICE_EXPIRY_DAYS 90

static void vaonExpireKnownDevices(NSMutableArray *devices) {
	long long cutoff = vaonToday() - VAON_KNOWN_DEVICE_EXPIRY_DAYS;
	NSArray *pinned = vaonPinnedIdentifiers();
	//a pin can point at an identifier the accessory has since renumbered, so protect by the same rule
	//vaonPinRank resolves with: the identifier itself, then the name of whatever record carries it
	NSMutableSet *pinnedNames = [NSMutableSet set];
	NSMutableSet *pinnedKeys = [NSMutableSet set];
	for(NSDictionary *record in devices){
		if(![pinned containsObject:record[@"identifier"]]) continue;
		if(record[@"name"]) [pinnedNames addObject:record[@"name"]];
		[pinnedKeys addObject:vaonDeviceKey(record[@"identifier"], record[@"name"])];
	}
	NSMutableArray *expired = [NSMutableArray array];
	for(NSDictionary *record in devices){
		if([record[@"lastSeen"] longLongValue] > cutoff) continue;
		if([pinned containsObject:record[@"identifier"]]) continue;
		if(record[@"name"] && [pinnedNames containsObject:record[@"name"]]) continue;
		if([pinnedKeys containsObject:vaonDeviceKey(record[@"identifier"], record[@"name"])]) continue;
		[expired addObject:record];
	}
	if(!expired.count) return;
	[devices removeObjectsInArray:expired];
	vaonKnownDevicesDirty = TRUE;
}

static NSMutableArray *vaonKnownDeviceList() {
	if(!vaonKnownDevices){
		BOOL changed = FALSE;
		vaonKnownDevices = vaonNormalizeKnownDevices([prefs objectForKey:@"knownDevices"], &changed);
		if(changed) vaonKnownDevicesDirty = TRUE;
		vaonCompactKnownDevices(vaonKnownDevices);
	}
	return vaonKnownDevices;
}

static void vaonReloadKnownDevices() {
	vaonKnownDevices = nil;
	vaonKnownDevicesDirty = FALSE;
}

static void vaonFlushKnownDevices() {
	if(vaonKnownDevicesDirty && vaonKnownDevices){
		[prefs setObject:vaonKnownDevices forKey:@"knownDevices"];
	}
	vaonKnownDevicesDirty = FALSE;
}

//resolve a colour from a mode/custom pref pair
static UIColor *vaonColorForMode(NSString *mode, NSString *customColor, UIColor *defaultColor) {
	if([mode isEqualToString:@"custom"]) return colorFromHexString(customColor);
	if([mode isEqualToString:@"system"]) return [UIColor systemBlueColor];
	return defaultColor;
}

//upsert a device into the shared knownDevices store; glyph is captured once, writes only on change.
//source is @"bluetooth" for BluetoothManager records and nil for BatteryCenter ones; a BatteryCenter
//record replaces the Bluetooth record of the same device, since it carries the real glyph and battery
static void vaonUpsertKnownDevice(NSString *identifier, NSString *name, long long productId, UIImage *glyph, long long percentage, NSString *source) {
	if(identifier.length == 0) return;
	NSMutableArray *devices = vaonKnownDeviceList();
	//match on the collapsed key, not the raw identifier, so a reconnection that renumbers the accessory
	//updates its record instead of adding another one
	NSString *key = vaonDeviceKey(identifier, name);
	NSUInteger idx = NSNotFound;
	for(NSUInteger i = 0; i < devices.count; i++){
		if([vaonDeviceKey(devices[i][@"identifier"], devices[i][@"name"]) isEqualToString:key]){ idx = i; break; }
	}
	NSDictionary *old = (idx == NSNotFound) ? nil : devices[idx];
	//keep the stored identifier so any pin pointing at it keeps working
	if(old) identifier = old[@"identifier"] ?: identifier;
	BOOL hasGlyph = (old[@"glyph"] != nil);
	long long today = vaonToday();
	BOOL changed = (old == nil)
		|| [old[@"lastSeen"] longLongValue] != today
		|| ![(old[@"name"] ?: @"") isEqualToString:(name ?: @"")]
		|| [old[@"productIdentifier"] longLongValue] != productId
		|| [old[@"lastPercentage"] longLongValue] != percentage
		|| (!hasGlyph && glyph != nil)
		|| ![(old[@"source"] ?: @"") isEqualToString:(source ?: @"")];
	if(!changed) return;
	NSMutableDictionary *record = old ? [old mutableCopy] : [NSMutableDictionary dictionary];
	record[@"identifier"] = identifier;
	if(name) record[@"name"] = name;
	record[@"productIdentifier"] = @(productId);
	record[@"lastPercentage"] = @(percentage);
	record[@"lastSeen"] = @(today);
	if(source) record[@"source"] = source; else [record removeObjectForKey:@"source"];
	if(glyph && !hasGlyph){
		NSData *png = UIImagePNGRepresentation(glyph);
		if(png) record[@"glyph"] = png;
	}
	if(idx == NSNotFound) [devices addObject:record]; else devices[idx] = record;

	//drop the Bluetooth stand-in for this device now that BatteryCenter knows it, and move its pin over
	if(source == nil && name.length){
		NSMutableArray *stale = [NSMutableArray array];
		for(NSDictionary *d in devices){
			if([d[@"source"] isEqualToString:@"bluetooth"] && [d[@"name"] isEqualToString:name] && ![d[@"identifier"] isEqualToString:identifier]){
				[stale addObject:d];
			}
		}
		if(stale.count){
			NSMutableArray *pinned = [vaonPinnedIdentifiers() mutableCopy];
			BOOL pinsChanged = FALSE;
			for(NSDictionary *d in stale){
				NSUInteger p = [pinned indexOfObject:d[@"identifier"]];
				if(p != NSNotFound){
					if([pinned containsObject:identifier]) [pinned removeObjectAtIndex:p];
					else pinned[p] = identifier;
					pinsChanged = TRUE;
				}
				[devices removeObject:d];
			}
			if(pinsChanged) [prefs setObject:pinned forKey:@"pinnedDeviceIdentifiers"];
		}
	}

	vaonKnownDevicesDirty = TRUE;
}

//record a live connected device; the internal iPhone battery is only recorded when it is shown, so it
//can appear in the Pinned Devices list and be sorted. skip the glyph fetch once already captured
static void vaonRecordDevice(BCBatteryDevice *device) {
	if(!device) return;
	if([device isInternal] && hideInternal) return;
	NSString *ident = [device identifier];
	NSString *key = vaonDeviceKey(ident, [device name]);
	BOOL haveGlyph = NO;
	for(NSDictionary *d in vaonKnownDeviceList()){
		if([vaonDeviceKey(d[@"identifier"], d[@"name"]) isEqualToString:key] && d[@"glyph"]){ haveGlyph = YES; break; }
	}
	UIImage *glyph = haveGlyph ? nil : [device batteryWidgetGlyph];
	vaonUpsertKnownDevice(ident, [device name], [device productIdentifier], glyph, [device percentCharge], nil);
}

//an accessory can be connected without BluetoothManager having set the flag that connectedDevices
//filters on: the manager only learns of a connection from a notification, so everything already
//connected when it was built is missing that flag. a live service count corroborates the connection
static BOOL vaonBluetoothIsConnected(BluetoothDevice *device) {
	if(!device) return FALSE;
	if([device connected]) return TRUE;
	if([device respondsToSelector:@selector(connectedServicesCount)] && [device connectedServicesCount] > 0) return TRUE;
	return FALSE;
}

//BatteryCenter only lists accessories that report a battery level to iOS, so speakers and soundbars
//that never send one are invisible to it. BluetoothManager enumerates everything. connectedDevices
//misses whatever was already connected when the manager was built, which is the state after every
//respring, so pairedDevices is walked as well and filtered down to what is actually connected
static NSArray *vaonConnectedBluetoothAccessories() {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		if(!NSClassFromString(@"BluetoothManager")){
			dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_LAZY);
		}
	});
	Class managerClass = NSClassFromString(@"BluetoothManager");
	if(!managerClass || ![managerClass respondsToSelector:@selector(sharedInstance)]) return @[];
	BluetoothManager *manager = [managerClass sharedInstance];
	if(![manager respondsToSelector:@selector(connectedDevices)]) return @[];

	NSMutableArray *devices = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for(BluetoothDevice *device in [manager connectedDevices] ?: @[]){
		NSString *address = [device address];
		if(address.length == 0 || [seen containsObject:address]) continue;
		[seen addObject:address];
		[devices addObject:device];
	}
	if([manager respondsToSelector:@selector(pairedDevices)]){
		for(BluetoothDevice *device in [manager pairedDevices] ?: @[]){
			NSString *address = [device address];
			if(address.length == 0 || [seen containsObject:address]) continue;
			if(!vaonBluetoothIsConnected(device)) continue;
			[seen addObject:address];
			[devices addObject:device];
		}
	}
	return devices;
}

//true while the accessory is in the set gathered this pass. the cells have to agree with whatever the
//gather decided, or a device shows up and then renders as disconnected
static BOOL vaonBluetoothStillConnected(BluetoothDevice *device) {
	if(!device) return FALSE;
	NSString *address = [device address];
	for(BluetoothDevice *other in connectedBluetoothAccessories){
		if(other == device || (address.length && [[other address] isEqualToString:address])) return TRUE;
	}
	return vaonBluetoothIsConnected(device);
}

//the accessory's battery percentage, or -1 when it reports none. accessories with no real level still
//answer YES to supportsBatteryLevel and hand back 1 as a placeholder, so anything at or below 1 is
//treated as no reading rather than a device about to die
static long long vaonBluetoothPercent(BluetoothDevice *device) {
	if(![device respondsToSelector:@selector(batteryLevel)]) return -1;
	int level = [device batteryLevel];
	if(level <= 1 || level > 100) return -1;
	return level;
}

//record a connected Bluetooth accessory under its address so it can be pinned even with no battery.
//skipped when BatteryCenter already stores this name, since that record is the better one
static void vaonRecordBluetoothDevice(BluetoothDevice *device, long long percent) {
	NSString *address = [device address];
	if(address.length == 0) return;
	NSString *name = [device name];
	if(name.length){
		for(NSDictionary *d in vaonKnownDeviceList()){
			if(![d[@"source"] isEqualToString:@"bluetooth"] && [d[@"name"] isEqualToString:name]) return;
		}
	}
	vaonUpsertKnownDevice(address, name, (long long)[device productId], nil, percent, @"bluetooth");
}

//returns a user-chosen SF Symbol glyph for a device name, or nil to use the default battery glyph
static UIImage *vaonCustomGlyphForName(NSString *name) {
	if(name.length == 0) return nil;
	for(NSDictionary *d in vaonKnownDeviceList()){
		if([d[@"name"] isEqualToString:name]){
			NSString *sym = d[@"customGlyph"];
			if(sym.length) return [UIImage systemImageNamed:sym];
		}
	}
	return nil;
}

//add cells for pinned devices that aren't currently connected, from persisted data
static void vaonSeedPinnedDevices() {
	NSArray *pinned = vaonPinnedIdentifiers();
	if(pinned.count == 0) return;
	NSArray *known = vaonKnownDeviceList();
	if(known.count == 0) return;
	for(NSString *pid in pinned){
		NSDictionary *record = nil;
		for(NSDictionary *d in known){ if([d[@"identifier"] isEqualToString:pid]){ record = d; break; } }
		if(!record) continue;
		NSString *rname = record[@"name"];
		//skip if a cell with this identifier OR the same name (e.g. reconnected under another id) is shown
		BOOL alreadyShown = FALSE;
		for(VaonDeviceBatteryCell *sub in batteryHStackView.subviews){
			if([sub.deviceIdentifier isEqualToString:pid] || (rname.length && [sub.deviceName isEqualToString:rname])){ alreadyShown = TRUE; break; }
		}
		if(alreadyShown) continue;
		VaonDeviceBatteryCell *cell = [[VaonDeviceBatteryCell alloc] initWithFrame:batteryHStackView.bounds persistedRecord:record];
		cell.pinned = TRUE;
		[batteryHStackView addArrangedSubview:cell];
		cell.alpha = 1;
		[cell updateOutlineColor];
		[cell updatePercentageColor];
		[cell newAnimateOuterLayerToCurrentPercentage];
	}
}

//rank of a cell within the pinned order (matched by identifier or name); non-pinned rank last
static NSInteger vaonPinRank(VaonDeviceBatteryCell *cell, NSArray *pinned, NSArray *known) {
	for(NSUInteger i = 0; i < pinned.count; i++){
		NSString *pid = pinned[i];
		if([cell.deviceIdentifier isEqualToString:pid]) return (NSInteger)i;
		for(NSDictionary *d in known){
			if([d[@"identifier"] isEqualToString:pid] && [d[@"name"] isEqualToString:cell.deviceName]) return (NSInteger)i;
		}
	}
	return NSIntegerMax;
}

//order the shown cells: pinned devices first (in pinned order), everything else after
static void vaonSortBatteryCells() {
	NSArray *pinned = vaonPinnedIdentifiers();
	if(pinned.count == 0) return;
	NSArray *known = vaonKnownDeviceList();
	NSArray *sorted = [[batteryHStackView arrangedSubviews] sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(VaonDeviceBatteryCell *a, VaonDeviceBatteryCell *b){
		NSInteger ra = vaonPinRank(a, pinned, known);
		NSInteger rb = vaonPinRank(b, pinned, known);
		if(ra < rb) return NSOrderedAscending;
		if(ra > rb) return NSOrderedDescending;
		return NSOrderedSame;
	}];
	for(VaonDeviceBatteryCell *c in sorted){ [batteryHStackView addArrangedSubview:c]; }
}

//the flat list of battery cells, whether they currently sit loose in the stack or grouped in pages
static NSArray *vaonAllBatteryCells() {
	NSMutableArray *cells = [NSMutableArray array];
	if(!batteryHStackView) return cells;
	for(UIView *sub in batteryHStackView.arrangedSubviews){
		if([sub isKindOfClass:[VaonDeviceBatteryCell class]]){
			[cells addObject:sub];
		} else {
			//page container: pageView -> inner stack -> cells
			for(UIView *inner in sub.subviews){
				for(UIView *c in inner.subviews){
					if([c isKindOfClass:[VaonDeviceBatteryCell class]]) [cells addObject:c];
				}
			}
		}
	}
	return cells;
}

//pull every cell out of its page container so the update/dedup loops only ever see plain cells
static void vaonFlattenPages() {
	if(!batteryHStackView) return;
	NSArray *cells = vaonAllBatteryCells();
	for(UIView *sub in [batteryHStackView.arrangedSubviews copy]){
		[batteryHStackView removeArrangedSubview:sub];
		[sub removeFromSuperview];
	}
	for(VaonDeviceBatteryCell *c in cells){ [batteryHStackView addArrangedSubview:c]; }
}

//group the ordered cells into one centered container per page of devicesPerPage; paging snaps per page
static void vaonLayoutPages() {
	if(!batteryHStackView) return;
	vaonFlattenPages();
	vaonSortBatteryCells();
	NSArray *cells = [batteryHStackView.arrangedSubviews copy];
	NSInteger n = devicesPerPage < 1 ? 1 : devicesPerPage;
	NSInteger count = cells.count;
	//the scroll view width equals the vaon view width; use it directly (bounds may not be laid out yet)
	CGFloat pageWidth = customWidthEnabled ? customWidth : dockWidth;
	if(pageWidth <= 0) pageWidth = batteryScrollView.bounds.size.width;
	NSInteger numPages = (count == 0) ? 0 : (count + n - 1) / n;
	//the Custom Spacing adjuster now only fine-tunes the gap between cells inside a page
	CGFloat interCell = horizontalSpacingBetweenDevicesEnabled ? horizontalSpacingBetweenDevices : 12;
	for(UIView *v in cells){ [batteryHStackView removeArrangedSubview:v]; [v removeFromSuperview]; }
	batteryHStackView.spacing = 0;
	batteryHStackView.layoutMarginsRelativeArrangement = NO;
	batteryHStackView.distribution = UIStackViewDistributionFill;
	for(NSInteger p = 0; p < numPages; p++){
		UIView *pageView = [[UIView alloc] init];
		pageView.translatesAutoresizingMaskIntoConstraints = NO;
		[pageView.widthAnchor constraintEqualToConstant:pageWidth].active = YES;
		UIStackView *inner = [[UIStackView alloc] init];
		inner.axis = UILayoutConstraintAxisHorizontal;
		inner.alignment = UIStackViewAlignmentCenter;
		inner.spacing = interCell;
		inner.translatesAutoresizingMaskIntoConstraints = NO;
		[pageView addSubview:inner];
		//content-sized inner stack, centered horizontally so the page's cells sit in the middle
		[inner.centerXAnchor constraintEqualToAnchor:pageView.centerXAnchor].active = YES;
		[inner.topAnchor constraintEqualToAnchor:pageView.topAnchor].active = YES;
		[inner.bottomAnchor constraintEqualToAnchor:pageView.bottomAnchor].active = YES;
		for(NSInteger k = 0; k < n; k++){
			NSInteger idx = p * n + k;
			if(idx >= count) break;
			[inner addArrangedSubview:cells[idx]];
		}
		[batteryHStackView addArrangedSubview:pageView];
	}
	batteryScrollView.scrollEnabled = (numPages > 1);
	if(batteryPageControl){
		batteryPageControl.numberOfPages = numPages;
		BOOL canShow = (showPageDots && numPages > 1);
		batteryPageControl.hidden = !canShow;
		//when set to only-while-swiping the dots sit idle at alpha 0 and fade in on drag
		if(canShow) batteryPageControl.alpha = pageDotsOnlyWhileSwiping ? 0.0 : 1.0;
	}
}

//tracks the current battery page for the dots and for remembering it across opens
@interface VaonScrollDelegate : NSObject <UIScrollViewDelegate>
@end
@implementation VaonScrollDelegate
	-(void)vaonFadeDotsIn {
		if(pageDotsOnlyWhileSwiping && batteryPageControl && !batteryPageControl.hidden){
			[UIView animateWithDuration:0.15 animations:^{ batteryPageControl.alpha = 1.0; }];
		}
	}
	-(void)vaonFadeDotsOut {
		if(pageDotsOnlyWhileSwiping && batteryPageControl && !batteryPageControl.hidden){
			[UIView animateWithDuration:0.35 delay:0.4 options:UIViewAnimationOptionBeginFromCurrentState animations:^{ batteryPageControl.alpha = 0.0; } completion:nil];
		}
	}
	-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
		CGFloat w = scrollView.bounds.size.width;
		if(w <= 0) return;
		NSInteger page = (NSInteger)((scrollView.contentOffset.x + w / 2.0) / w);
		currentBatteryPage = page;
		if(batteryPageControl) batteryPageControl.currentPage = page;
	}
	-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
		[self vaonFadeDotsIn];
	}
	-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
		if(!decelerate) [self vaonFadeDotsOut];
	}
	-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
		if(rememberLastPage) [prefs setObject:@(currentBatteryPage) forKey:@"lastBatteryPage"];
		[self vaonFadeDotsOut];
	}
@end

//delegate for outline animation
@implementation StrokeEndAnimationDelegate 

	-(instancetype)initWithCell:(VaonDeviceBatteryCell *)cell {
		self = [super init];
		self.cell = cell;
		return self;
	}

	//keeps the outline at a static position when it finishes animating
    -(void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
		if(flag){
			[self.cell pulsateOutline];
		}
	}

@end

//delegate for charging devices' pulsating color animation 
@implementation PulsateColorAnimationDelegate

	-(instancetype)initWithCell:(VaonDeviceBatteryCell *)cell nextAnimation:(CAAnimation *)nextAnimation {
		self = [super init];
		self.cell = cell;
		self.nextAnimation = nextAnimation;
		return self;
	}
	
	//when the animation finishes change the color and start another pulsate animation
    -(void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
		if(flag && self.cell && self.cell.pulsateActive){
			if([self.cell shouldPulsateOutline]){
				[self.cell.circleOutlineLayer addAnimation:self.nextAnimation forKey:kCATransition];
			}else{
				//drop the held pulse frame so the restored colour is actually visible
				[self.cell.circleOutlineLayer removeAnimationForKey:kCATransition];
				[self.cell updateOutlineColor];
			}
		}
	}
@end

//Individual battery cell for each device
@implementation VaonDeviceBatteryCell

	//convenience init for a live connected device
    -(instancetype)initWithFrame:(CGRect)arg1 device:(BCBatteryDevice *)connectedDevice {
        UIImage *glyph = [connectedDevice batteryWidgetGlyph];
        UIImage *custom = vaonCustomGlyphForName(connectedDevice.name);
        if(custom) glyph = custom;
        return [self initWithFrame:arg1 device:connectedDevice glyphImage:glyph percentage:[connectedDevice percentCharge] name:connectedDevice.name identifier:connectedDevice.identifier productIdentifier:connectedDevice.productIdentifier disconnected:FALSE];
    }

	//convenience init for a persisted (pinned, currently disconnected) device from stored data
    -(instancetype)initWithFrame:(CGRect)arg1 persistedRecord:(NSDictionary *)record {
        UIImage *glyph = nil;
        NSString *sym = record[@"customGlyph"];
        if(sym.length) glyph = [UIImage systemImageNamed:sym];
        if(!glyph && record[@"glyph"]) glyph = [UIImage imageWithData:record[@"glyph"]];
        //Bluetooth-sourced records have no battery widget glyph to store
        if(!glyph) glyph = [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
        return [self initWithFrame:arg1 device:nil glyphImage:glyph percentage:[record[@"lastPercentage"] longLongValue] name:record[@"name"] identifier:record[@"identifier"] productIdentifier:[record[@"productIdentifier"] longLongValue] disconnected:TRUE];
    }

	//convenience init for a device that only BluetoothManager knows about. there is no battery widget
	//glyph for these, so fall back to a generic one the user can swap in the Pinned Devices list
    -(instancetype)initWithFrame:(CGRect)arg1 bluetoothDevice:(BluetoothDevice *)device percentage:(long long)percentage {
        NSString *name = [device name];
        UIImage *glyph = vaonCustomGlyphForName(name);
        if(!glyph) glyph = [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
        self = [self initWithFrame:arg1 device:nil glyphImage:glyph percentage:percentage name:name identifier:[device address] productIdentifier:(long long)[device productId] disconnected:FALSE];
        self.bluetoothDevice = device;
        [self updateDevicePercentageLabel];
        return self;
    }

	//designated init: works from either a live device or persisted values
    -(instancetype)initWithFrame:(CGRect)arg1 device:(BCBatteryDevice *)connectedDevice glyphImage:(UIImage *)pGlyph percentage:(long long)pPercentage name:(NSString *)pName identifier:(NSString *)pIdentifier productIdentifier:(long long)pProductId disconnected:(BOOL)isDisconnected {
		//initialize view placement
        self = [super initWithFrame:arg1];
        if(!self) return nil;

        self.device = connectedDevice;
		if(customBatteryCellSizeEnabled){
        	self.cellWidth = CGFloat(customBatteryCellSize);
		} else {
			self.cellWidth = CGFloat(50);
		}
        self.devicePercentage = pPercentage;

        self.axis = UILayoutConstraintAxisVertical;
        self.alignment = UIStackViewAlignmentCenter;
		if(paddingBetweenGlyphAndLabelEnabled){
			self.spacing = paddingBetweenGlyphAndLabel;
			if(paddingBetweenGlyphAndLabel > 0) {
				self.distribution = UIStackViewDistributionEqualSpacing;
			}
		} else {
			self.spacing = 10;
			self.distribution = UIStackViewDistributionEqualSpacing;
		}
        self.clipsToBounds = FALSE;
        self.backgroundColor = [UIColor clearColor];
        self.translatesAutoresizingMaskIntoConstraints = FALSE;

    
		//initialize background blur effect
		if ([batteryGlyphBackgroundMode isEqualToString:@"system"]) {
			self.circleBackgroundBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
		} else if ([batteryGlyphBackgroundMode isEqualToString:@"dark"]) {
			self.circleBackgroundBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
		} else if ([batteryGlyphBackgroundMode isEqualToString:@"light"]) {
			self.circleBackgroundBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialLight];
		}
        self.circleBackgroundVisualEffectView = [[UIVisualEffectView alloc] initWithEffect:self.circleBackgroundBlurEffect];
        self.circleBackgroundVisualEffectView.layer.cornerRadius = self.cellWidth/2;
        self.circleBackgroundVisualEffectView.clipsToBounds = TRUE;
        self.circleBackgroundVisualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.circleBackgroundVisualEffectView.frame = self.bounds;
       	self.circleBackgroundVisualEffectView.contentMode = UIViewContentModeScaleAspectFill;

		//battery percentage label; updateDevicePercentageLabel sets both the text and the font
        self.devicePercentageLabel = [[UILabel alloc] init];
        [self updateDevicePercentageLabel];
        self.devicePercentageLabel.frame = self.bounds;
		self.devicePercentageLabel.textColor = normalBatteryColor;
		self.devicePercentageLabel.textAlignment = NSTextAlignmentCenter;
		//pin the label to the height a percentage would take. the enlarged infinity glyph would
		//otherwise grow the cell, and a centre aligned row pushes half that growth into the glyph
		[self.devicePercentageLabel.heightAnchor constraintEqualToConstant:[self percentageLabelHeight]].active = TRUE;

		//view placement and constraints for background blur
        self.circleBackgroundVisualEffectView.translatesAutoresizingMaskIntoConstraints = FALSE;
        [self.circleBackgroundVisualEffectView.widthAnchor constraintEqualToConstant:self.cellWidth].active = TRUE;
        [self.circleBackgroundVisualEffectView.heightAnchor constraintEqualToConstant:self.cellWidth].active = TRUE;

		[self addArrangedSubview:self.circleBackgroundVisualEffectView];

		//initialize circular outline path
        self.circleOutlinePath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.circleBackgroundVisualEffectView.contentView.center.x+self.cellWidth/2,self.circleBackgroundVisualEffectView.contentView.center.y+self.cellWidth/2)
            radius:self.cellWidth/2
            startAngle:[self degreesToRadians:(-90)]
            endAngle:[self degreesToRadians:(270)]
            clockwise:TRUE];
        self.circleOutlineLayer = [[CAShapeLayer alloc] init];
        self.circleOutlineLayer.bounds = self.bounds;
        self.circleOutlineLayer.fillColor = [UIColor clearColor].CGColor;
		self.circleOutlineLayer.strokeStart = 0;
		self.circleOutlineLayer.strokeEnd = 0;
        self.circleOutlineLayer.path = [self.circleOutlinePath CGPath];
        self.circleOutlineLayer.lineWidth = self.cellWidth/10;
		self.circleOutlineLayer.masksToBounds = FALSE;
        [self.layer addSublayer:self.circleOutlineLayer];
		
		//rounds the corners of the outline layer 
		if(roundOutlineCorners){
			self.circleOutlineLayer.lineCap = kCALineCapRound;
		}

		//initialize device image and its constraints
		self.deviceGlyphView = [[UIImageView alloc] initWithImage:pGlyph];
		self.deviceGlyphView.image = [self.deviceGlyphView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		if ([batteryGlyphBackgroundMode isEqualToString:@"system"]) {
			[self.deviceGlyphView setTintColor:[UIColor labelColor]];
		} else if ([batteryGlyphBackgroundMode isEqualToString:@"dark"]) {
			[self.deviceGlyphView setTintColor:[UIColor lightTextColor]];
		} else if ([batteryGlyphBackgroundMode isEqualToString:@"light"]) {
			[self.deviceGlyphView setTintColor:[UIColor darkTextColor]];
		}

		CGFloat glyphAspectRatio = self.deviceGlyphView.frame.size.width/self.deviceGlyphView.frame.size.height;

		if(customDeviceGlyphSizeEnabled) {
			[self.deviceGlyphView.heightAnchor constraintEqualToConstant:customDeviceGlyphSize].active = TRUE;
			[self.deviceGlyphView.widthAnchor constraintEqualToConstant:customDeviceGlyphSize * glyphAspectRatio].active = TRUE;
		} else {
			[self.deviceGlyphView.heightAnchor constraintEqualToConstant:self.cellWidth * 0.6 ].active = TRUE;
			[self.deviceGlyphView.widthAnchor constraintEqualToConstant:self.cellWidth * 0.6 * glyphAspectRatio].active = TRUE;
		}

		if(!hidePercentageLabel) {
			[self addArrangedSubview:self.devicePercentageLabel];
		}
		[self.circleBackgroundVisualEffectView.contentView addSubview:self.deviceGlyphView];
        self.deviceGlyphView.translatesAutoresizingMaskIntoConstraints = FALSE;
        [self.deviceGlyphView.centerXAnchor constraintEqualToAnchor:self.circleBackgroundVisualEffectView.centerXAnchor].active = TRUE;
        [self.deviceGlyphView.centerYAnchor constraintEqualToAnchor:self.circleBackgroundVisualEffectView.centerYAnchor].active = TRUE;

		[self.circleBackgroundVisualEffectView setNeedsDisplay];
        self.deviceName = pName;
		self.deviceIdentifier = pIdentifier;
		self.deviceProductIdentifier = pProductId;

        return self;
    }

    -(CGFloat)degreesToRadians:(CGFloat)arg1 {
        return arg1*(M_PI/180);
    }

    @synthesize cellWidth;

    -(CGFloat)getCellWidth {
        return cellWidth;
    }

    -(void)setCellWidth:(CGFloat)arg1 {
        cellWidth = arg1;
    }

    -(void)addPercentageSymbolToLabel {
		if(!hidePercent){
        	[self.devicePercentageString appendString:@"%"];
		}
    }

    -(long long)getDevicePercentage {
        if(self.bluetoothDevice) {
            return vaonBluetoothPercent(self.bluetoothDevice);
        }
        //persisted (deviceless) cells keep their stored last-known percentage
        if(!self.device) {
            return self.devicePercentage;
        }
        return [self.device percentCharge];
    }

	-(void)updateDevicePercentage {
		self.devicePercentage = [self getDevicePercentage];
	}

	//false for devices iOS has no battery figure for, such as a mains powered speaker
	-(BOOL)hasBatteryReading {
		return self.devicePercentage >= 0;
	}

	//updates a device's percentage and adjusts the label accordingly 
	-(UIFont *)percentageFont {
		CGFloat size = customPercentageFontSizeEnabled ? customPercentageFontSize : 12;
		return [UIFont systemFontOfSize:size weight:(enableBoldPercentage ? UIFontWeightBold : UIFontWeightRegular)];
	}

	//the row height every cell's label is held to, whatever it ends up rendering
	-(CGFloat)percentageLabelHeight {
		return ceil([self percentageFont].lineHeight);
	}

    -(void)updateDevicePercentageLabel {
		[self updateDevicePercentage];
		//the ring still needs the refresh above, but a hidden label is not in the hierarchy
		if(hidePercentageLabel) return;
		UIFont *font = [self percentageFont];

		//an infinity sign on its own for devices with no level to report. it carries much less ink than
		//a two or three digit percentage, so size it up. the label keeps its fixed height so the cell
		//does not grow, and the glyph is nudged onto the same centre line as the digits beside it
		if(![self hasBatteryReading]){
			UIFont *large = [UIFont systemFontOfSize:font.pointSize * 1.5 weight:(enableBoldPercentage ? UIFontWeightBold : UIFontWeightRegular)];
			self.devicePercentageLabel.font = large;
			self.devicePercentageLabel.transform = CGAffineTransformMakeTranslation(0, vaonInfinitySignNudge(font, large, [self percentageLabelHeight]));
			self.devicePercentageString = [NSMutableString stringWithString:@"∞"];
			self.devicePercentageLabel.text = self.devicePercentageString;
			return;
		}

		self.devicePercentageLabel.transform = CGAffineTransformIdentity;
		self.devicePercentageLabel.font = font;
        self.devicePercentageString = [NSMutableString stringWithFormat:@"%lld",self.devicePercentage];
		[self addPercentageSymbolToLabel];
        self.devicePercentageLabel.text = self.devicePercentageString;
    }

	-(CGFloat)devicePercentageAsProgress {
		//a full ring for devices with no level, to match the infinity sign
		if(![self hasBatteryReading]) return 1;
		double progress = self.devicePercentage;
		return progress/100;
	}

	//true if the device is the iPhone/iPad, false otherwise
	-(BOOL)isDeviceInternal {
		return [self.device isInternal];
	}

	//BluetoothManager cells carry no BCBatteryDevice, so their connected state comes from the accessory
	-(BOOL)isDeviceConnected {
		if(self.bluetoothDevice) return vaonBluetoothStillConnected(self.bluetoothDevice);
		return [self.device isConnected];
	}

	-(BOOL)isLowPowerModeOn {
		return [self.device isBatterySaverModeActive];
	}

	-(BOOL)isBatteryLow {
		if(self.bluetoothDevice) return [self hasBatteryReading] && self.devicePercentage <= 20;
		return [self.device isLowBattery];
	}

	//updates the outline color depending on the device's charging/connected state
	-(void)updateOutlineColor {
		if([self isDeviceInternal] && [self isLowPowerModeOn] && ![self.device isCharging]){
			if([customLowPowerColorMode isEqualToString:@"custom"]) {
				self.circleOutlineLayer.strokeColor = colorFromHexString(customLowPowerColor).CGColor;
			} else if([customLowPowerColorMode isEqualToString:@"system"]) {
				self.circleOutlineLayer.strokeColor = [UIColor systemBlueColor].CGColor;
			} else {
				self.circleOutlineLayer.strokeColor = lowPowerModeColor.CGColor;
			}
		} else if([self isBatteryLow] && (![self.device isCharging])){
			if([customLowBatteryColorMode isEqualToString:@"custom"]) {
				self.circleOutlineLayer.strokeColor = colorFromHexString(customLowBatteryColor).CGColor;
			} else if([customLowBatteryColorMode isEqualToString:@"system"]) {
				self.circleOutlineLayer.strokeColor = [UIColor systemBlueColor].CGColor;
			} else {
				self.circleOutlineLayer.strokeColor = lowBatteryColor.CGColor;
			}
		} else if([self.device isCharging] && pulsateChargingOutline){
			if([customChargingColorMode isEqualToString:@"custom"]) {
				self.circleOutlineLayer.strokeColor = colorFromHexString(customChargingColor).CGColor;
			} else if([customChargingColorMode isEqualToString:@"system"]) {
				self.circleOutlineLayer.strokeColor = [UIColor systemBlueColor].CGColor;
			} else {
				self.circleOutlineLayer.strokeColor = normalBatteryColor.CGColor;
			}
		} else {
			if(![self isDeviceConnected]){
				if(![self hasBatteryReading]){
					self.circleOutlineLayer.strokeColor = vaonColorForMode(customNoBatteryDisconnectedColorMode, customNoBatteryDisconnectedColor, [UIColor systemGrayColor]).CGColor;
				} else if([customDisconnectedDeviceColorMode isEqualToString:@"custom"]) {
					self.circleOutlineLayer.strokeColor = colorFromHexString(customDisconnectedDeviceColor).CGColor;
				} else if([customDisconnectedDeviceColorMode isEqualToString:@"system"]) {
					self.circleOutlineLayer.strokeColor = [UIColor systemBlueColor].CGColor;
				} else {
					self.circleOutlineLayer.strokeColor = [UIColor systemGrayColor].CGColor;
				}
			} else if(![self hasBatteryReading]){
				self.circleOutlineLayer.strokeColor = [self noBatteryConnectedColor].CGColor;
			} else {
				if([customConnectedDeviceColorMode isEqualToString:@"custom"]) {
					self.circleOutlineLayer.strokeColor = colorFromHexString(customConnectedDeviceColor).CGColor;
				} else if([customConnectedDeviceColorMode isEqualToString:@"system"]) {
					self.circleOutlineLayer.strokeColor = [UIColor systemBlueColor].CGColor;
				} else {
					self.circleOutlineLayer.strokeColor = normalBatteryColor.CGColor;
				}
			}
		}
	}

	-(UIColor *)noBatteryConnectedColor {
		return vaonColorForMode(customNoBatteryConnectedColorMode, customNoBatteryConnectedColor, normalBatteryColor);
	}

	//charging devices pulse when the pref is on; devices with no level pulse to show they are live
	-(BOOL)shouldPulsateOutline {
		if(![self isDeviceConnected]) return FALSE;
		if(![self hasBatteryReading]) return TRUE;
		return pulsateChargingOutline && [self.device isCharging];
	}

	//starts the pulsating color animation sequence
	-(void)pulsateOutline {
		//the ring animation that calls this lands a quarter second late, so it can arrive after the
		//switcher has gone; without this the chain would restart with nothing on screen
		if(!vaonShown) return;
		if([self shouldPulsateOutline]){
			self.pulsateActive = TRUE;
			CAMediaTimingFunction *animationColorTimingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];

			//initializes animations. the cell holds both, so the delegates can reference the other one
			//weakly; retaining it there would leave the pair alive for the life of the process
			CABasicAnimation *normalToBright = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
			CABasicAnimation *brightToNormal = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
			self.pulsateToBright = normalToBright;
			self.pulsateToNormal = brightToNormal;

			//assigns delegate to animations 
			PulsateColorAnimationDelegate *normalToBrightDelegate = [[PulsateColorAnimationDelegate alloc] initWithCell:self nextAnimation:brightToNormal];
			normalToBright.delegate = normalToBrightDelegate;
			PulsateColorAnimationDelegate *brightToNormalDelegate = [[PulsateColorAnimationDelegate alloc] initWithCell:self nextAnimation:normalToBright];
			brightToNormal.delegate = brightToNormalDelegate;

			if(![self hasBatteryReading]) {
				normalToBright.fromValue = id([self noBatteryConnectedColor].CGColor);
			} else if([customChargingColorMode isEqualToString:@"custom"]) {
				normalToBright.fromValue = id(colorFromHexString(customChargingColor).CGColor);
			} else if([customChargingColorMode isEqualToString:@"system"]) {
				normalToBright.fromValue = id([UIColor systemBlueColor].CGColor);
			} else {
				normalToBright.fromValue = id(normalBatteryColor.CGColor);
			}
			normalToBright.toValue = id(darkGrayColor.CGColor);
			normalToBright.duration = 2;
			normalToBright.timingFunction = animationColorTimingFunction;
			[normalToBright setFillMode:kCAFillModeForwards];
			[normalToBright setRemovedOnCompletion:FALSE];

			brightToNormal.fromValue = normalToBright.toValue;
			brightToNormal.toValue = normalToBright.fromValue; 
			brightToNormal.duration = 2;
			brightToNormal.timingFunction = animationColorTimingFunction;
			[brightToNormal setFillMode:kCAFillModeForwards];
			[brightToNormal setRemovedOnCompletion:FALSE];
			
			[self.circleOutlineLayer addAnimation:normalToBright forKey:kCATransition];
		}
	}

	//ends the chain. the halves hold their last frame, so the resting colour has to be put back
	-(void)stopPulsatingOutline {
		if(!self.pulsateActive) return;
		self.pulsateActive = FALSE;
		[self.circleOutlineLayer removeAnimationForKey:kCATransition];
		self.pulsateToBright = nil;
		self.pulsateToNormal = nil;
		[self updateOutlineColor];
	}

	//makes percentage label green if charging
	-(void)updatePercentageColor {
		if([self.device isCharging]){
			if([customChargingColorMode isEqualToString:@"custom"]) {
				self.devicePercentageLabel.textColor = colorFromHexString(customChargingColor);
			} else if([customChargingColorMode isEqualToString:@"system"]) {
				self.devicePercentageLabel.textColor = [UIColor systemBlueColor];
			} else {
				self.devicePercentageLabel.textColor = normalBatteryColor;
			}
		}else {
			if ([batteryTextColor isEqualToString:@"system"]) {
				self.devicePercentageLabel.textColor = [UIColor labelColor];
			} else if ([batteryTextColor isEqualToString:@"dark"]) {
				self.devicePercentageLabel.textColor = [UIColor blackColor];
			} else if ([batteryTextColor isEqualToString:@"light"]) {
				self.devicePercentageLabel.textColor = [UIColor whiteColor];
			} else if ([batteryTextColor isEqualToString:@"custom"]) {
				self.devicePercentageLabel.textColor = colorFromHexString(customBatteryTextColor);
			}
		}
	}

	//animates outline position along the bezier path
	-(void)newAnimateOuterLayerToCurrentPercentage{
		self.percentageAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
		StrokeEndAnimationDelegate *delegate = [[StrokeEndAnimationDelegate alloc] initWithCell:self];
		self.percentageAnimation.delegate = delegate;
		self.percentageAnimation.fromValue = @(0.0);
		self.percentageAnimation.toValue = @([self devicePercentageAsProgress]);
		self.percentageAnimation.duration = 0.25;
		[self.percentageAnimation setFillMode:kCAFillModeForwards];
		[self.percentageAnimation setRemovedOnCompletion:TRUE];
		CAMediaTimingFunction *animationTimingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		self.percentageAnimation.timingFunction = animationTimingFunction;
		[self.circleOutlineLayer addAnimation:self.percentageAnimation forKey:kCATransition];
		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue
						forKey:kCATransactionDisableActions];
		self.circleOutlineLayer.strokeEnd = [self devicePercentageAsProgress];
		[CATransaction commit];
	}

	//returns outline position to zero
	-(void)newAnimateOuterLayerToZero {
		self.circleOutlineLayer.strokeEnd = 0;
	}

@end

//initialize the battery view
void initBatteryView(UIView *view){

	if(!vaonScrollDelegate) vaonScrollDelegate = [[VaonScrollDelegate alloc] init];

	//initialize horizontal scroll view
	batteryScrollView = [[UIScrollView alloc] initWithFrame:view.bounds];
	batteryScrollView.scrollsToTop = FALSE;
	batteryScrollView.directionalLockEnabled = TRUE;
	batteryScrollView.alwaysBounceVertical = FALSE;
	batteryScrollView.alwaysBounceHorizontal = FALSE;
	batteryScrollView.showsHorizontalScrollIndicator = TRUE;
	batteryScrollView.showsVerticalScrollIndicator = FALSE;

	//paging: one page shows devicesPerPage cells, swipe horizontally between pages
	batteryScrollView.pagingEnabled = TRUE;
	batteryScrollView.showsHorizontalScrollIndicator = FALSE;
	batteryScrollView.delegate = vaonScrollDelegate;

	//initialize horizontal stack view
	batteryHStackView = [[UIStackView alloc] initWithFrame:batteryScrollView.bounds];
	batteryHStackView.axis = UILayoutConstraintAxisHorizontal;
	batteryHStackView.alignment = UIStackViewAlignmentCenter;
	batteryHStackView.distribution = UIStackViewDistributionFill;

	//page dots
	batteryPageControl = [[UIPageControl alloc] init];
	batteryPageControl.hidesForSinglePage = YES;
	batteryPageControl.userInteractionEnabled = FALSE;

	//adds to the view hierarchy
	[view addSubview:batteryScrollView];
	[batteryScrollView addSubview:batteryHStackView];
	[view addSubview:batteryPageControl];

	//scroll view constraints
	batteryScrollView.translatesAutoresizingMaskIntoConstraints = FALSE;
	[batteryScrollView.centerXAnchor constraintEqualToAnchor:view.centerXAnchor].active = TRUE;
	[batteryScrollView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor].active = TRUE;
	[batteryScrollView.heightAnchor constraintEqualToAnchor:view.heightAnchor].active = TRUE;
	[batteryScrollView.widthAnchor constraintEqualToAnchor:view.widthAnchor].active = TRUE;

	//stack pinned to the scroll content guide so its width drives contentSize (page count)
	batteryHStackView.translatesAutoresizingMaskIntoConstraints = FALSE;
	[batteryHStackView.leadingAnchor constraintEqualToAnchor:batteryScrollView.contentLayoutGuide.leadingAnchor].active = TRUE;
	[batteryHStackView.trailingAnchor constraintEqualToAnchor:batteryScrollView.contentLayoutGuide.trailingAnchor].active = TRUE;
	[batteryHStackView.centerYAnchor constraintEqualToAnchor:batteryScrollView.frameLayoutGuide.centerYAnchor].active = TRUE;

	//page control constraints: vertical mode rotates the dots into a column pinned to the left edge,
	//otherwise the dots sit in a row at the bottom centre. rotation is applied around the centre so
	//constraining the centre keeps the dot column at a fixed left inset without clipping
	batteryPageControl.translatesAutoresizingMaskIntoConstraints = FALSE;
	if(verticalPageDots){
		batteryPageControl.transform = CGAffineTransformMakeRotation(M_PI_2);
		[batteryPageControl.centerXAnchor constraintEqualToAnchor:view.leadingAnchor constant:8].active = TRUE;
		[batteryPageControl.centerYAnchor constraintEqualToAnchor:view.centerYAnchor].active = TRUE;
	} else {
		[batteryPageControl.centerXAnchor constraintEqualToAnchor:view.centerXAnchor].active = TRUE;
		[batteryPageControl.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-2].active = TRUE;
	}
}

//initialize the base background blur view
void initBaseVaonView(UIView* view) {
	if ([backgroundMode isEqualToString:@"system"]) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
	} else if ([backgroundMode isEqualToString:@"dark"]) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
	} else if ([backgroundMode isEqualToString:@"light"]) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialLight];
	}
	view.clipsToBounds = TRUE;
	view.layer.cornerRadius = vaonViewCornerRadius;
	view.alpha = 0;
	view.backgroundColor = [UIColor clearColor];

	vaonBlurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
	vaonBlurView.frame = view.bounds;
	vaonBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	if(hideBackground) {
		vaonBlurView.effect = nil;
	}
	[view addSubview:vaonBlurView];
}

void updateScrollWidthAndTouchPassthrough() {
	//the result only depends on the stack width; skip the recompute when it has not moved
	static CGFloat lastWidth = -1;
	CGFloat currentWidth = batteryHStackView.bounds.size.width;
	if(currentWidth == lastWidth) return;
	lastWidth = currentWidth;
	if((customWidthEnabled && batteryHStackView.bounds.size.width > customWidth) || batteryHStackView.bounds.size.width > dockWidth){
		batteryScrollView.scrollEnabled = TRUE;
			vaonView.userInteractionEnabled = TRUE;
			batteryScrollView.userInteractionEnabled = TRUE;
			batteryHStackView.userInteractionEnabled = TRUE;
			if(switcherContentView) {
				switcherContentView.userInteractionEnabled = TRUE;
			}
		}else{
			batteryScrollView.scrollEnabled = FALSE;
			vaonView.userInteractionEnabled = FALSE;
			batteryScrollView.userInteractionEnabled = FALSE;
			batteryHStackView.userInteractionEnabled = FALSE;
			if(switcherContentView) {
				switcherContentView.userInteractionEnabled = FALSE;
			}
	}
}



//move the scroll view to the page for this open: the remembered page, or page 0. called before the
//fade so the correct page shows from the start instead of flashing the previously left page
static void vaonRestoreBatteryPage() {
	if(!batteryScrollView) return;
	[batteryScrollView layoutIfNeeded];
	NSInteger pages = batteryPageControl.numberOfPages;
	NSInteger target = rememberLastPage ? [[prefs objectForKey:@"lastBatteryPage"] integerValue] : 0;
	if(target < 0) target = 0;
	if(target >= pages) target = pages > 0 ? pages - 1 : 0;
	currentBatteryPage = target;
	CGFloat pw = customWidthEnabled ? customWidth : dockWidth;
	if(pw <= 0) pw = batteryScrollView.bounds.size.width;
	if(pw > 0) batteryScrollView.contentOffset = CGPointMake(target * pw, 0);
	if(batteryPageControl) batteryPageControl.currentPage = target;
}

void updateBatteryView(){
		vaonFlattenPages();
		vaonReloadKnownDevices();


		//update list of bluetooth devices
		connectedBluetoothDevices = [[%c(BCBatteryDeviceController) _sharedPowerSourceController] connectedDevices];
		NSMutableArray *subviewsToBeAdded = [[NSMutableArray alloc] init];
		//names BatteryCenter already covers, so the Bluetooth pass below does not double them up
		NSMutableSet *batteryCenterNames = [NSMutableSet set];

		//loops through and finds new devices to add 
		for(BCBatteryDevice *device in connectedBluetoothDevices){

			vaonRecordDevice(device);
			if(device){
				NSString *bcName = [device name];
				if(bcName.length) [batteryCenterNames addObject:bcName];
				BOOL duplicate = FALSE;
				VaonDeviceBatteryCell *newCell = [[VaonDeviceBatteryCell alloc] initWithFrame:batteryHStackView.bounds device:device];
				

				//skip devices already shown; dedup against the current cells, not a growing name list
				for(VaonDeviceBatteryCell *subview in batteryHStackView.subviews){
					if([subview.deviceName isEqualToString:newCell.deviceName] || [subview.deviceIdentifier isEqualToString:newCell.deviceIdentifier]){
						duplicate = TRUE;
					}
				}
				if(![batteryHStackView.subviews containsObject:newCell] && !duplicate){
					//add all devices that are not the iPhone/iPad
					if(![device isInternal]){
						[subviewsToBeAdded addObject:newCell];
					} else{
						//displays the iphone if hideInternal is off
						if(!hideInternal){
							[subviewsToBeAdded addObject:newCell];
						}
					}
				}
			}
		}

		//second pass over everything connected over Bluetooth, whether or not it reports a battery, so
		//a speaker iOS has no percentage for still shows and can still be pinned
		connectedBluetoothAccessories = vaonConnectedBluetoothAccessories();
		for(BluetoothDevice *btDevice in connectedBluetoothAccessories){
			NSString *btName = [btDevice name];
			NSString *btAddress = [btDevice address];
			if(btAddress.length == 0) continue;
			if(btName.length && [batteryCenterNames containsObject:btName]) continue;

			long long percent = vaonBluetoothPercent(btDevice);
			vaonRecordBluetoothDevice(btDevice, percent);

			BOOL duplicate = FALSE;
			for(VaonDeviceBatteryCell *subview in batteryHStackView.subviews){
				if([subview.deviceIdentifier isEqualToString:btAddress] || (btName.length && [subview.deviceName isEqualToString:btName])){ duplicate = TRUE; break; }
			}
			for(VaonDeviceBatteryCell *pending in subviewsToBeAdded){
				if([pending.deviceIdentifier isEqualToString:btAddress] || (btName.length && [pending.deviceName isEqualToString:btName])){ duplicate = TRUE; break; }
			}
			if(duplicate) continue;

			[subviewsToBeAdded addObject:[[VaonDeviceBatteryCell alloc] initWithFrame:batteryHStackView.bounds bluetoothDevice:btDevice percentage:percent]];
		}



		//animate and add subviews to the hstack
		for(VaonDeviceBatteryCell *subview in subviewsToBeAdded){

			if(subview.device || subview.bluetoothDevice){
				[batteryHStackView addArrangedSubview:subview];
				subview.alpha = 0;
				//fade in new devices
				[UIView animateWithDuration:0.3 animations:^ {
					subview.alpha = 1;

				}
				completion:^(BOOL finished) {
					//when finished animate the outer layer to its percentage position
					if(finished){
						[subview newAnimateOuterLayerToCurrentPercentage];
						updateScrollWidthAndTouchPassthrough();
					}
				}];	
			}
		}



		//update device view properties
		for(VaonDeviceBatteryCell *subview in batteryHStackView.subviews){

			BOOL adoptedAccessory = FALSE;
			if(!subview.device && !subview.bluetoothDevice) {
				for(BCBatteryDevice *device in connectedBluetoothDevices) {
					if([device.name isEqual:subview.deviceName]) {
						subview.device = device;
					}
				}
				//a pinned cell seeded from storage starts with no accessory at all, and the second pass
				//skips it as a duplicate, so without this it stays stuck on the disconnected colour for
				//as long as the cell lives. match on address first, name second
				if(!subview.device){
					for(BluetoothDevice *btDevice in connectedBluetoothAccessories) {
						if([[btDevice address] isEqualToString:subview.deviceIdentifier]
							|| (subview.deviceName.length && [[btDevice name] isEqualToString:subview.deviceName])){
							subview.bluetoothDevice = btDevice;
							adoptedAccessory = TRUE;
							break;
						}
					}
				}
			}

			//the ring animation that starts the pulse already ran for this open, before the accessory was
			//adopted, so kick it again or the cell sits still until the next time the switcher opens
			if(adoptedAccessory){
				[subview updateOutlineColor];
				[subview updatePercentageColor];
				[subview newAnimateOuterLayerToCurrentPercentage];
			}

			//re-point Bluetooth cells at the current accessory object so a reconnect is picked up
			if(subview.bluetoothDevice && !vaonBluetoothStillConnected(subview.bluetoothDevice)) {
				for(BluetoothDevice *btDevice in connectedBluetoothAccessories) {
					if([[btDevice address] isEqualToString:subview.deviceIdentifier]) {
						subview.bluetoothDevice = btDevice;
						break;
					}
				}
			}

			//checks if the device is not connected anymore
			if(subview.bluetoothDevice ? !vaonBluetoothStillConnected(subview.bluetoothDevice)
				: (!(subview.device && [connectedBluetoothDevices containsObject:subview.device]) && ![subview.device isConnected])){
				//if keep is turned on, keep the device and just update its properties
				if(keepDisconnectedDevices || subview.pinned){
					if(subview.device == nil){
						for(BCBatteryDevice *device in connectedBluetoothDevices){
							if([subview.deviceName isEqual:[device name]]){
								subview.device = device;
								[subview updateOutlineColor];
								[subview updatePercentageColor];
							}
						}
					}
				} else{
					//remove subviews that aren't connected if keepDisconnectedDevices is turned off
					//fade out
					[UIView animateWithDuration:0.3 animations:^ {
						subview.alpha = 0;
					}
					completion:^(BOOL finished) {
						[subview removeFromSuperview];
					}];
				}
			}


			//updates outline color and percentage values 
			if(keepDisconnectedDevices || subview.pinned){	
				[subview updateOutlineColor];
				[subview updatePercentageColor];

				//if the device is still connected update its battery data
				if([subview isDeviceConnected]){
					[subview updateDevicePercentage];
					[subview updateDevicePercentageLabel];
				}
			} else {
				[subview updateDevicePercentageLabel];
				[subview updateOutlineColor];
				[subview updatePercentageColor];
				[subview updateDevicePercentage];
			}
		}

		vaonSeedPinnedDevices();
		vaonLayoutPages();

		//restore the page for this open: last-viewed page, or page 0
		vaonRestoreBatteryPage();

		if(vaonKnownDevices) vaonExpireKnownDevices(vaonKnownDevices);
		vaonFlushKnownDevices();
}




//fade in the base Vaon view
void fadeViewIn(UIView *view, CGFloat duration){
	//group and center the pages before the fade so the animation never shows the flat left-aligned cells
	vaonLayoutPages();
	//land on the right page before fading so the previously left page does not flash on open
	vaonRestoreBatteryPage();
	updateScrollWidthAndTouchPassthrough();

	//in landscape offset mode the position comes purely from the constraints (which carry the
	//landscape offsets); skip the frame based placement that would otherwise pin it to the portrait
	//resting spot and mask the offset, and let a layout pass apply the constraint position
	BOOL landscapeActive = landscapeOffsetEnabled && vaonIsLandscape(view);

	CGRect mainScreen = [[UIScreen mainScreen] bounds];

	if(!landscapeActive && firstSlideIn && !enableFlyInOut){
		if(customVerticalOffsetEnabled){
			view.frame = CGRectMake(view.frame.origin.x, mainScreen.size.height + customVerticalOffset - view.frame.size.height, view.frame.size.width, view.frame.size.height);
		} else {
			view.frame = CGRectMake(view.frame.origin.x, mainScreen.size.height - 25 - view.frame.size.height, view.frame.size.width, view.frame.size.height);
		}
	}
	if(landscapeActive){
		[view.superview layoutIfNeeded];
	}

	[UIView animateWithDuration:duration animations:^ {
		if(!landscapeActive && firstSlideIn && enableFlyInOut){
			if(customVerticalOffsetEnabled){
				view.frame = CGRectMake(view.frame.origin.x, mainScreen.size.height + customVerticalOffset - view.frame.size.height, view.frame.size.width, view.frame.size.height);
			} else {
				view.frame = CGRectMake(view.frame.origin.x, mainScreen.size.height - 25 - view.frame.size.height, view.frame.size.width, view.frame.size.height);
			}
		}

		view.alpha = 1;

	} completion:^(BOOL finished) {
		if(view.alpha==1){
			if([selectedModule isEqual:@"battery"]){
				if(finished){
					for(VaonDeviceBatteryCell *subview in vaonAllBatteryCells()){
						if(firstSlideIn) {
							[subview newAnimateOuterLayerToCurrentPercentage];
						}
					}
					stockHidden = FALSE;
					updateBatteryView();
					vaonShown = TRUE;
				}
			}
		}
		firstSlideIn = true;
	}];
}

//fade the base Vaon view out
void fadeViewOut(UIView *view, CGFloat duration){
	vaonShown = FALSE;
	//animate all the outlines back to their original position
	for(VaonDeviceBatteryCell *subview in vaonAllBatteryCells()){
		[subview stopPulsatingOutline];
		[subview newAnimateOuterLayerToZero];
	}
	//landscape offset mode keeps the view at its constraint position and just fades, so the slide
	//offscreen (which uses the portrait screen height) does not fight the offset
	BOOL landscapeActive = landscapeOffsetEnabled && vaonIsLandscape(view);
	CGRect mainScreen = [[UIScreen mainScreen] bounds];

	if(!landscapeActive && !enableFlyInOut) {
		view.frame = CGRectMake(view.frame.origin.x, mainScreen.size.height + 200, view.frame.size.width, view.frame.size.height);
	}

	[UIView animateWithDuration:duration animations:^ {
		if(!landscapeActive && enableFlyInOut) {
			view.frame = CGRectMake(view.frame.origin.x, mainScreen.size.height + 200, view.frame.size.width, view.frame.size.height);
		}

		view.alpha = 0;

	} completion:^(BOOL finished) {
			stockHidden = TRUE;
			updateScrollWidthAndTouchPassthrough();
	}];	
}


//true when the switcher is currently landscape. SpringBoard stays portrait-locked so the window
//scene orientation is unreliable inside the switcher; trust the physical device orientation first,
//then fall back to any landscape interface/geometry signal when the device is flat or unknown
static BOOL vaonIsLandscape(UIView *view){
	UIDeviceOrientation dev = [UIDevice currentDevice].orientation;
	if(UIDeviceOrientationIsLandscape(dev)) return YES;
	if(UIDeviceOrientationIsPortrait(dev)) return NO;
	UIWindowScene *scene = view.window.windowScene;
	if(scene && UIInterfaceOrientationIsLandscape(scene.interfaceOrientation)) return YES;
	CGRect b = view.window ? view.window.bounds : view.bounds;
	if(b.size.width > 0 && b.size.height > 0) return b.size.width > b.size.height;
	return NO;
}

//place the vaon view for the current orientation. landscape uses its own offsets when enabled,
//otherwise it falls back to the portrait custom offsets (or the defaults). runs on every open so
//rotating between switcher opens re-tunes the position without rebuilding the view
static void vaonApplyOrientationLayout(UIView *host){
	if(!vaonBottomConstraint || !vaonCenterXConstraint) return;
	BOOL landscape = vaonIsLandscape(host);
	if(landscapeOffsetEnabled && landscape){
		vaonBottomConstraint.constant = vaonViewHeightCaptured + landscapeVerticalOffset;
		vaonCenterXConstraint.constant = landscapeHorizontalOffset;
	} else {
		vaonBottomConstraint.constant = customVerticalOffsetEnabled ? (vaonViewHeightCaptured + customVerticalOffset) : -25;
		vaonCenterXConstraint.constant = customHorizontalOffsetEnabled ? customHorizontalOffset : 0;
	}
}

%hook SBSwitcherAppSuggestionContentView

	//creates vaonview for normal/non-grid app switcher
	-(void)didMoveToWindow {
		%orig;
		if([selectedModule isEqual:@"none"]) return;
		switcherContentView = self;
		{
			CGFloat mainScreen = [[UIScreen mainScreen] bounds].size.height;
			//iOS 16: the old main switcher VC is gone, so dockWidth is never set there
			if(dockWidth == 0){
				dockWidth = [[UIScreen mainScreen] bounds].size.width * 0.943;
			}
			//iOS 16: attach here for grid too, since the grid VC path no longer runs
			if(!vaonViewIsInitialized){

				vaonView = [[UIView alloc] init];


				initBaseVaonView(vaonView);

				if([selectedModule isEqual:@"battery"]){	
					initBatteryView(vaonView);
				}


				[self addSubview:vaonView];


				CGFloat vaonViewHeight = vaonView.frame.size.height;
				vaonViewHeightCaptured = vaonViewHeight;

				//keep the bottom/centerX constraints so their constants can be re-tuned per orientation
				//without rebuilding the view; vaonApplyOrientationLayout sets the right constants
				vaonView.translatesAutoresizingMaskIntoConstraints = false;
				vaonBottomConstraint = [vaonView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-25];
				vaonBottomConstraint.active = TRUE;
				vaonCenterXConstraint = [vaonView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:0];
				vaonCenterXConstraint.active = TRUE;
				vaonApplyOrientationLayout(self);
				if(customWidthEnabled){
					[vaonView.widthAnchor constraintEqualToConstant:customWidth].active = TRUE;
				} else{
					[vaonView.widthAnchor constraintEqualToConstant:dockWidth].active = TRUE;
				}
				if(customHeightEnabled){
					[vaonView.heightAnchor constraintEqualToConstant:customHeight].active = TRUE;
				} else{
					[vaonView.heightAnchor constraintEqualToConstant:(0.12*mainScreen)].active = TRUE;
				}

				vaonViewIsInitialized = TRUE;
			}	
		}
		
		{
			SBApplication *frontApp = [(SpringBoard*)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
			NSString *currentAppDisplayID = [frontApp bundleIdentifier];
			vaonOpenFrontApp = [currentAppDisplayID copy];



			updateScrollWidthAndTouchPassthrough();

			//re-place for the current orientation, then suppress entirely when hidden in landscape
			vaonApplyOrientationLayout(self);
			BOOL suppressForLandscape = hideInLandscape && vaonIsLandscape(self);
			if(vaonView){
				if(suppressForLandscape){
					vaonView.hidden = YES;
					vaonShown = FALSE;
				} else {
					vaonView.hidden = NO;
				}
			}

			if(self.window != nil && !suppressForLandscape){
				// opening the app switcher from the home screen
				if(currentAppDisplayID==nil && stockHidden){
					if(enableDelay) {
							[delayedFadeInTimer invalidate];
							delayedFadeInTimer = [NSTimer scheduledTimerWithTimeInterval:fadeInDelay target:self selector:@selector(delayedFadeViewIn:) userInfo:nil repeats:NO];
					} else {
						fadeViewIn(vaonView, 0.4);
					}
				} else {
					if(stockHidden){
						if(enableDelay) {
							[delayedFadeInTimer invalidate];
							delayedFadeInTimer = [NSTimer scheduledTimerWithTimeInterval:fadeInDelay target:self selector:@selector(delayedFadeViewIn:) userInfo:nil repeats:NO];
						} else {
							fadeViewIn(vaonView, 0.4);
						}
					}
				}
			} 
		}

	}

	%new
	-(void)delayedFadeViewIn:(NSTimer *)timer {
		[timer invalidate];
		if(timer == delayedFadeInTimer) delayedFadeInTimer = nil;
		fadeViewIn(vaonView, 0.4);
	}

	//only claim touches that land on the battery strip while it can page; let everything else fall
	//through so the switcher's home gesture is not hijacked by the overlay (fixes leave-anim drift)
	-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
		if(vaonView && vaonShown && batteryScrollView && batteryScrollView.scrollEnabled){
			CGPoint p = [self convertPoint:point toView:batteryScrollView];
			if([batteryScrollView pointInside:p withEvent:event]){
				UIView *hit = [batteryScrollView hitTest:p withEvent:event];
				return hit ?: batteryScrollView;
			}
			return nil;
		}
		return %orig;
	}

%end


//iOS 16 moved SBMainSwitcherViewController's methods onto this coordinator (not a view controller)
%group iOS16SwitcherCoordinator
%hook SBMainSwitcherControllerCoordinator

	//card launch and swipe-to-home leave the switcher through here; animate the slide-down fade
	-(void)_configureRequest:(id)arg1 forSwitcherTransitionRequest:(id)arg2 withEventLabel:(id)arg3 {
		%orig;
		if(vaonView && vaonShown){
			fadeViewOut(vaonView, 0.3);
			//if the leave gesture is cancelled and the switcher stays up, vaon would be left hidden.
			//after the transition settles, re-show it only when the switcher is still on screen
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				//a cancelled leave keeps the same frontmost app and the switcher on screen; if a
				//different app was launched (or we went home), skip so vaon does not flash back in
				SBApplication *nowFront = [(SpringBoard*)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
				NSString *nowID = [nowFront bundleIdentifier];
				BOOL sameFront = (nowID == vaonOpenFrontApp) || [nowID isEqualToString:vaonOpenFrontApp];
				if(sameFront && switcherContentView && switcherContentView.window != nil && !vaonShown && vaonView && !vaonView.hidden){
					fadeViewIn(vaonView, 0.25);
				}
			});
		}
	}

%end
%end


//dock launches go through iconTapped: at tap time, before the switcher is snapshotted; hide synchronously
%group iOS16FloatingDock
%hook SBHIconManager
	-(void)iconTapped:(id)arg1 {
		if(vaonView){
			fadeViewOut(vaonView, 0.0);
		}
		%orig;
	}
%end
%end


//SquidGesture Pro compat: a dock gesture runs its action through invokeActivity:withEvent:, which
//dismisses the switcher without hitting the normal paths; hide synchronously before it runs
%group VaonSquidGestureCompat
%hook SFActivityAction
	-(void)invokeActivity:(id)arg1 withEvent:(id)arg2 {
		if(vaonView){
			fadeViewOut(vaonView, 0.0);
		}
		%orig;
	}
%end
%end




void updateSettings(){
	[prefs registerDefaults:@{
		@"isEnabled": @TRUE,
		@"moduleSelection": @"battery",
		@"hideBackground": @FALSE,
		@"backgroundMode": @"system",
		@"enableFlyInOut": @TRUE,
		@"enableDelay": @FALSE,
		@"fadeInDelay": @0.5,
		@"customHeightEnabled": @FALSE,
		@"customHeight": @113,
		@"customWidthEnabled": @FALSE,
		@"customWidth": @400,
		@"customVerticalOffsetEnabled": @FALSE,
		@"customVerticalOffset": @-80,
		@"customHorizontalOffsetEnabled": @FALSE,
		@"customHorizontalOffset": @0,
		@"hideInLandscape": @FALSE,
		@"landscapeOffsetEnabled": @FALSE,
		@"landscapeHorizontalOffset": @0,
		@"landscapeVerticalOffset": @-80,
		@"hideInternal": @FALSE,
		@"hidePercentageLabel": @FALSE,
		@"hidePercent": @FALSE,
		@"enableBoldPercentage": @TRUE,
		@"roundOutlineCorners": @TRUE,
		@"pulsateChargingOutline": @TRUE,
		@"keepDisconnectedDevices": @TRUE,
		@"devicesPerPage": @4,
		@"showPageDots": @TRUE,
		@"pageDotsOnlyWhileSwiping": @FALSE,
		@"verticalPageDots": @FALSE,
		@"rememberLastPage": @FALSE,
		@"batteryTextColor": @"system",
		@"customBatteryTextColor": @"#FFFFFF",
		@"batteryGlyphBackgroundMode": @"system",
		@"customDeviceGlyphSizeEnabled": @FALSE,
		@"customDeviceGlyphSize": @30,
		@"customBatteryCellSizeEnabled": @FALSE,
		@"customBatteryCellSize": @50,
		@"customPercentageFontSizeEnabled": @FALSE,
		@"customPercentageFontSize": @12,
		@"paddingBetweenGlyphAndLabelEnabled": @FALSE,
		@"paddingBetweenGlyphAndLabel": @0,
		@"horizontalSpacingBetweenDevicesEnabled": @FALSE,
		@"horizontalSpacingBetweenDevices": @30,
		@"customConnectedDeviceColorMode": @"default",
		@"customConnectedDeviceColor": @"#33b5e5",
		@"customDisconnectedDeviceColorMode": @"default",
		@"customDisconnectedDeviceColor": @"#33b5e5",
		@"customLowPowerColorMode": @"default",
		@"customLowPowerColor": @"#33b5e5",
		@"customLowBatteryColorMode": @"default",
		@"customLowBatteryColor": @"#33b5e5",
		@"customChargingColorMode": @"default",
		@"customChargingColor": @"#33b5e5",
		@"customNoBatteryConnectedColorMode": @"custom",
		@"customNoBatteryConnectedColor": @"#8560d6",
		@"customNoBatteryDisconnectedColorMode": @"default",
		@"customNoBatteryDisconnectedColor": @"#8560d6"
	}];

	isEnabled = [[prefs objectForKey:@"isEnabled"] boolValue];
	selectedModule = [prefs objectForKey:@"moduleSelection"];
	hideBackground = [[prefs objectForKey:@"hideBackground"] boolValue];
	backgroundMode = [prefs objectForKey:@"backgroundMode"];
	enableFlyInOut = [[prefs objectForKey:@"enableFlyInOut"] boolValue];
	enableDelay = [[prefs objectForKey:@"enableDelay"] boolValue];
	fadeInDelay = [[prefs objectForKey:@"fadeInDelay"] floatValue];
	customHeightEnabled = [[prefs objectForKey:@"customHeightEnabled"] boolValue];
	customHeight = [[prefs objectForKey:@"customHeight"] floatValue];
	customWidthEnabled = [[prefs objectForKey:@"customWidthEnabled"] boolValue];
	customWidth = [[prefs objectForKey:@"customWidth"] floatValue];
	customVerticalOffsetEnabled = [[prefs objectForKey:@"customVerticalOffsetEnabled"] boolValue];
	customVerticalOffset = [[prefs objectForKey:@"customVerticalOffset"] floatValue];
	customHorizontalOffsetEnabled = [[prefs objectForKey:@"customHorizontalOffsetEnabled"] boolValue];
	customHorizontalOffset = [[prefs objectForKey:@"customHorizontalOffset"] floatValue];
	hideInLandscape = [[prefs objectForKey:@"hideInLandscape"] boolValue];
	landscapeOffsetEnabled = [[prefs objectForKey:@"landscapeOffsetEnabled"] boolValue];
	landscapeHorizontalOffset = [[prefs objectForKey:@"landscapeHorizontalOffset"] floatValue];
	landscapeVerticalOffset = [[prefs objectForKey:@"landscapeVerticalOffset"] floatValue];
	hideInternal = [[prefs objectForKey:@"hideInternal"] boolValue];
	hidePercentageLabel = [[prefs objectForKey:@"hidePercentageLabel"] boolValue];
	hidePercent = [[prefs objectForKey:@"hidePercent"] boolValue];
	enableBoldPercentage = [[prefs objectForKey:@"enableBoldPercentage"] boolValue];
	roundOutlineCorners = [[prefs objectForKey:@"roundOutlineCorners"] boolValue];
	pulsateChargingOutline = [[prefs objectForKey:@"pulsateChargingOutline"] boolValue];
	keepDisconnectedDevices = [[prefs objectForKey:@"keepDisconnectedDevices"] boolValue];
	devicesPerPage = [[prefs objectForKey:@"devicesPerPage"] integerValue];
	if(devicesPerPage < 1) devicesPerPage = 1;
	if(devicesPerPage > 10) devicesPerPage = 10;
	showPageDots = [[prefs objectForKey:@"showPageDots"] boolValue];
	pageDotsOnlyWhileSwiping = [[prefs objectForKey:@"pageDotsOnlyWhileSwiping"] boolValue];
	verticalPageDots = [[prefs objectForKey:@"verticalPageDots"] boolValue];
	rememberLastPage = [[prefs objectForKey:@"rememberLastPage"] boolValue];
	batteryTextColor = [prefs objectForKey:@"batteryTextColor"];
	customBatteryTextColor = [prefs objectForKey:@"customBatteryTextColor"];
	batteryGlyphBackgroundMode = [prefs objectForKey:@"batteryGlyphBackgroundMode"];
	customDeviceGlyphSizeEnabled = [[prefs objectForKey:@"customDeviceGlyphSizeEnabled"] boolValue];
	customDeviceGlyphSize = [[prefs objectForKey:@"customDeviceGlyphSize"] floatValue];
	customBatteryCellSizeEnabled = [[prefs objectForKey:@"customBatteryCellSizeEnabled"] boolValue];
	customBatteryCellSize = [[prefs objectForKey:@"customBatteryCellSize"] floatValue];
	customPercentageFontSizeEnabled = [[prefs objectForKey:@"customPercentageFontSizeEnabled"] boolValue];
	customPercentageFontSize = [[prefs objectForKey:@"customPercentageFontSize"] floatValue];
	paddingBetweenGlyphAndLabelEnabled = [[prefs objectForKey:@"paddingBetweenGlyphAndLabelEnabled"] boolValue];
	paddingBetweenGlyphAndLabel = [[prefs objectForKey:@"paddingBetweenGlyphAndLabel"] floatValue];
	horizontalSpacingBetweenDevicesEnabled = [[prefs objectForKey:@"horizontalSpacingBetweenDevicesEnabled"] boolValue];
	horizontalSpacingBetweenDevices = [[prefs objectForKey:@"horizontalSpacingBetweenDevices"] floatValue];
	customConnectedDeviceColorMode = [prefs objectForKey:@"customConnectedDeviceColorMode"];
	customConnectedDeviceColor = [prefs objectForKey:@"customConnectedDeviceColor"];
	customDisconnectedDeviceColorMode = [prefs objectForKey:@"customDisconnectedDeviceColorMode"];
	customDisconnectedDeviceColor = [prefs objectForKey:@"customDisconnectedDeviceColor"];
	customLowPowerColorMode = [prefs objectForKey:@"customLowPowerColorMode"];
	customLowPowerColor = [prefs objectForKey:@"customLowPowerColor"];
	customLowBatteryColorMode = [prefs objectForKey:@"customLowBatteryColorMode"];
	customLowBatteryColor = [prefs objectForKey:@"customLowBatteryColor"];
	customChargingColorMode = [prefs objectForKey:@"customChargingColorMode"];
	customChargingColor = [prefs objectForKey:@"customChargingColor"];
	customNoBatteryConnectedColorMode = [prefs objectForKey:@"customNoBatteryConnectedColorMode"];
	customNoBatteryConnectedColor = [prefs objectForKey:@"customNoBatteryConnectedColor"];
	customNoBatteryDisconnectedColorMode = [prefs objectForKey:@"customNoBatteryDisconnectedColorMode"];
	customNoBatteryDisconnectedColor = [prefs objectForKey:@"customNoBatteryDisconnectedColor"];
}

%ctor {
	prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
	updateSettings();

	//Vaon targets iOS 16. The version floor alone still admits later firmwares, and a hook on
	//a class that is not there installs silently and does nothing
	if(isEnabled && kCFCoreFoundationVersionNumber > 1900 && NSClassFromString(@"SBSwitcherAppSuggestionContentView")){
		//keep UIDevice.orientation populated so landscape detection works in the switcher
		if(![selectedModule isEqual:@"none"]){
			[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
		}

		%init;
		if(NSClassFromString(@"SBMainSwitcherControllerCoordinator")){
			%init(iOS16SwitcherCoordinator);
		}
		if(NSClassFromString(@"SBHIconManager")){
			%init(iOS16FloatingDock);
		}
		//only hook SquidGesture Pro's action class if it is actually installed
		if(NSClassFromString(@"SFActivityAction")){
			%init(VaonSquidGestureCompat);
		}

		//BluetoothManager reaches bluetoothd asynchronously, so build it well before the first switcher
		//open or the accessory list comes back empty. deferred so SpringBoard finishes its own setup
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			vaonConnectedBluetoothAccessories();
		});
	}
/**
Additional modules:
favorite contacts or an option for recents
device batteries
favorited apps
music player when you 
countdown 
airpod pro transparency and noise cancellation
weather/AQI view that's similar to battery view
**/
}