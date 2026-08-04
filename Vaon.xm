//credit to Dogbert for the icon

#import "Vaon.h"
#import <UIKit/UIKit.h>
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

UIColor *vaonViewBackgroundColor;
UIVisualEffectView *vaonBlurView;
UIBlurEffect *blurEffect;
UILabel *titleLabel;

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
long long currentSwitcherStyle;
BOOL stockHidden = TRUE;
//frontmost app bundle id captured when the switcher opened; used to tell a cancelled leave (same
//front app, switcher stays) from an app launch or going home (front app changes)
NSString *vaonOpenFrontApp;
//set at fade-in completion, cleared at fade-out start; stockHidden is unreliable on iOS 16
BOOL vaonShown = FALSE;

NSArray *connectedBluetoothDevices;

UIColor *normalBatteryColor = [UIColor colorWithRed:0.1882352941 green:0.8196078431 blue:0.3450980392 alpha: 1];
UIColor *lowPowerModeColor = [UIColor colorWithRed:1 green:0.8 blue:0 alpha:1];
UIColor *lowBatteryColor = [UIColor redColor];
UIColor *darkGrayColor = [UIColor colorWithRed:0.1746478873 green:0.2039215686 blue:0.1960784314 alpha: 1];

//timers to initiate animations
NSTimer *delayedFadeInTimer = nil;
NSTimer *delayedPulsateTimer = nil;


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

UIColor* colorFromHexString(NSString *hexString) {
    if(hexString.length == 0) return [UIColor clearColor];
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if([hexString hasPrefix:@"#"]) [scanner setScanLocation:1];
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

//upsert a device into the shared knownDevices store; glyph is captured once, writes only on change
static void vaonUpsertKnownDevice(NSString *identifier, NSString *name, long long productId, UIImage *glyph, long long percentage) {
	if(identifier.length == 0) return;
	NSArray *existing = [prefs objectForKey:@"knownDevices"];
	NSMutableArray *devices = existing ? [existing mutableCopy] : [NSMutableArray array];
	NSUInteger idx = NSNotFound;
	for(NSUInteger i = 0; i < devices.count; i++){
		if([devices[i][@"identifier"] isEqualToString:identifier]){ idx = i; break; }
	}
	NSDictionary *old = (idx == NSNotFound) ? nil : devices[idx];
	BOOL hasGlyph = (old[@"glyph"] != nil);
	BOOL changed = (old == nil)
		|| ![(old[@"name"] ?: @"") isEqualToString:(name ?: @"")]
		|| [old[@"productIdentifier"] longLongValue] != productId
		|| [old[@"lastPercentage"] longLongValue] != percentage
		|| (!hasGlyph && glyph != nil);
	if(!changed) return;
	NSMutableDictionary *record = old ? [old mutableCopy] : [NSMutableDictionary dictionary];
	record[@"identifier"] = identifier;
	if(name) record[@"name"] = name;
	record[@"productIdentifier"] = @(productId);
	record[@"lastPercentage"] = @(percentage);
	if(glyph && !hasGlyph){
		NSData *png = UIImagePNGRepresentation(glyph);
		if(png) record[@"glyph"] = png;
	}
	if(idx == NSNotFound) [devices addObject:record]; else devices[idx] = record;
	[prefs setObject:devices forKey:@"knownDevices"];
	[prefs synchronize];
}

//record a live connected device; the internal iPhone battery is only recorded when it is shown, so it
//can appear in the Pinned Devices list and be sorted. skip the glyph fetch once already captured
static void vaonRecordDevice(BCBatteryDevice *device) {
	if(!device) return;
	if([device isInternal] && hideInternal) return;
	NSString *ident = [device identifier];
	BOOL haveGlyph = NO;
	for(NSDictionary *d in [prefs objectForKey:@"knownDevices"]){
		if([d[@"identifier"] isEqualToString:ident] && d[@"glyph"]){ haveGlyph = YES; break; }
	}
	UIImage *glyph = haveGlyph ? nil : [device batteryWidgetGlyph];
	vaonUpsertKnownDevice(ident, [device name], [device productIdentifier], glyph, [device percentCharge]);
}

//returns a user-chosen SF Symbol glyph for a device name, or nil to use the default battery glyph
static UIImage *vaonCustomGlyphForName(NSString *name) {
	if(name.length == 0) return nil;
	NSArray *known = [prefs objectForKey:@"knownDevices"];
	for(NSDictionary *d in known){
		if([d[@"name"] isEqualToString:name]){
			NSString *sym = d[@"customGlyph"];
			if([sym isKindOfClass:[NSString class]] && sym.length){
				return [UIImage systemImageNamed:sym];
			}
		}
	}
	return nil;
}

//add cells for pinned devices that aren't currently connected, from persisted data
static void vaonSeedPinnedDevices() {
	NSArray *pinned = [prefs arrayForKey:@"pinnedDeviceIdentifiers"];
	if(pinned.count == 0) return;
	NSArray *known = [prefs objectForKey:@"knownDevices"];
	if(known.count == 0) return;
	for(NSString *pid in pinned){
		if(![pid isKindOfClass:[NSString class]]) continue;
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
	NSArray *pinned = [prefs arrayForKey:@"pinnedDeviceIdentifiers"] ?: @[];
	if(pinned.count == 0) return;
	NSArray *known = [prefs objectForKey:@"knownDevices"] ?: @[];
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
		[prefs setObject:@(currentBatteryPage) forKey:@"lastBatteryPage"];
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
		if(flag && pulsateChargingOutline){
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
		if(flag && pulsateChargingOutline){
			if([self.cell.device isCharging]){
				[self.cell.circleOutlineLayer addAnimation:self.nextAnimation forKey:kCATransition];
			}else{
				self.cell.circleOutlineLayer.strokeColor = normalBatteryColor.CGColor;
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
        if([sym isKindOfClass:[NSString class]] && sym.length){
            glyph = [UIImage systemImageNamed:sym];
        }
        if(!glyph){
            NSData *glyphData = record[@"glyph"];
            if([glyphData isKindOfClass:[NSData class]]) {
                glyph = [UIImage imageWithData:glyphData];
            }
        }
        return [self initWithFrame:arg1 device:nil glyphImage:glyph percentage:[record[@"lastPercentage"] longLongValue] name:record[@"name"] identifier:record[@"identifier"] productIdentifier:[record[@"productIdentifier"] longLongValue] disconnected:TRUE];
    }

	//designated init: works from either a live device or persisted values
    -(instancetype)initWithFrame:(CGRect)arg1 device:(BCBatteryDevice *)connectedDevice glyphImage:(UIImage *)pGlyph percentage:(long long)pPercentage name:(NSString *)pName identifier:(NSString *)pIdentifier productIdentifier:(long long)pProductId disconnected:(BOOL)isDisconnected {
        self.device = connectedDevice;
		if(customBatteryCellSizeEnabled){
        	self.cellWidth = CGFloat(customBatteryCellSize);
		} else {
			self.cellWidth = CGFloat(50);
		}
        self.devicePercentage = pPercentage;

		//initialize view placement
        self = [super initWithFrame:arg1];
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

		//battery percentage label
        self.devicePercentageLabel = [[UILabel alloc] init];
        [self updateDevicePercentageLabel];
        [self addPercentageSymbolToLabel];

		//font customization
		UIFont *devicePercentageLabelFont = [[UIFont alloc] init];
		//custom font size from prefs
		UIFontWeight percentageFontWeight;
		if(enableBoldPercentage) {
			percentageFontWeight = UIFontWeightBold;
		} else {
			percentageFontWeight = UIFontWeightRegular;
		}
		if(customPercentageFontSizeEnabled){
        	devicePercentageLabelFont = [UIFont systemFontOfSize:customPercentageFontSize weight:percentageFontWeight];
		} else{
        	devicePercentageLabelFont = [UIFont systemFontOfSize:12 weight:percentageFontWeight];
		}
        self.devicePercentageLabel.font = devicePercentageLabelFont;
        self.devicePercentageLabel.frame = self.bounds;
		self.devicePercentageLabel.textColor = normalBatteryColor;

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
        //persisted (deviceless) cells keep their stored last-known percentage
        if(!self.device) {
            return self.devicePercentage;
        }
        return [self.device percentCharge];
    }

	-(void)updateDevicePercentage {
		self.devicePercentage = [self getDevicePercentage];
	}

	//updates a device's percentage and adjusts the label accordingly 
    -(void)updateDevicePercentageLabel {
		[self updateDevicePercentage];
        self.devicePercentageString = [NSMutableString stringWithFormat:@"%lld",self.devicePercentage];
		[self addPercentageSymbolToLabel];
        self.devicePercentageLabel.text = self.devicePercentageString;
    }

	-(void)removeFromSuperview {
		[super removeFromSuperview];
	}

	-(CGFloat)devicePercentageAsProgress {
		double progress = self.devicePercentage;
		return progress/100;
	}

	//true if the device is the iPhone/iPad, false otherwise
	-(BOOL)isDeviceInternal {
		return [self.device isInternal];
	}

	-(BOOL)isLowPowerModeOn {
		return [self.device isBatterySaverModeActive];
	}

	-(BOOL)isBatteryLow {
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
			if(![self.device isConnected]){
				if([customDisconnectedDeviceColorMode isEqualToString:@"custom"]) {
					self.circleOutlineLayer.strokeColor = colorFromHexString(customDisconnectedDeviceColor).CGColor;
				} else if([customDisconnectedDeviceColorMode isEqualToString:@"system"]) {
					self.circleOutlineLayer.strokeColor = [UIColor systemBlueColor].CGColor;
				} else {
					self.circleOutlineLayer.strokeColor = [UIColor systemGrayColor].CGColor;
				}
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

	//starts the pulsating color animation sequence for charging devices
	-(void)pulsateOutline {
		if([self.device isCharging]){
			CAMediaTimingFunction *animationColorTimingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];

			//initializes animations
			CABasicAnimation *normalToBright = [CABasicAnimation animationWithKeyPath:@"strokeColor"];	
			CABasicAnimation *brightToNormal = [CABasicAnimation animationWithKeyPath:@"strokeColor"];

			//assigns delegate to animations 
			PulsateColorAnimationDelegate *normalToBrightDelegate = [[PulsateColorAnimationDelegate alloc] initWithCell:self nextAnimation:brightToNormal];
			normalToBright.delegate = normalToBrightDelegate;
			PulsateColorAnimationDelegate *brightToNormalDelegate = [[PulsateColorAnimationDelegate alloc] initWithCell:self nextAnimation:normalToBright];
			brightToNormal.delegate = brightToNormalDelegate;

			if([customChargingColorMode isEqualToString:@"custom"]) {
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
	vaonViewBackgroundColor = [UIColor colorNamed:@"clearColor"];
	if ([backgroundMode isEqualToString:@"system"]) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
	} else if ([backgroundMode isEqualToString:@"dark"]) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
	} else if ([backgroundMode isEqualToString:@"light"]) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialLight];
	}
	titleLabel = [[UILabel alloc] initWithFrame:view.bounds];
	view.clipsToBounds = TRUE;
	view.layer.cornerRadius = vaonViewCornerRadius;
	view.alpha = 0;
	view.backgroundColor = vaonViewBackgroundColor;

	vaonBlurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
	vaonBlurView.frame = view.bounds;
	vaonBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	if(hideBackground) {
		vaonBlurView.effect = nil;
	}
	[view addSubview:vaonBlurView];
}

void updateScrollWidthAndTouchPassthrough() {
	//the result only depends on the stack width and switcher style; skip recompute when both are unchanged
	//(this is called on every battery event, which fire frequently)
	static CGFloat lastWidth = -1;
	static long long lastStyle = -1;
	CGFloat currentWidth = batteryHStackView.bounds.size.width;
	if(currentWidth == lastWidth && currentSwitcherStyle == lastStyle) return;
	lastWidth = currentWidth;
	lastStyle = currentSwitcherStyle;
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


		//update list of bluetooth devices
		connectedBluetoothDevices = [[%c(BCBatteryDeviceController) _sharedPowerSourceController] connectedDevices];
		NSMutableArray *subviewsToBeAdded = [[NSMutableArray alloc] init];

		//loops through and finds new devices to add 
		for(BCBatteryDevice *device in connectedBluetoothDevices){

			vaonRecordDevice(device);
			if(device){
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



		//animate and add subviews to the hstack
		for(VaonDeviceBatteryCell *subview in subviewsToBeAdded){

			if(subview.device){
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
						[subviewsToBeAdded removeObject:subview];
						updateScrollWidthAndTouchPassthrough();
					}
				}];	
			}
		}



		//update device view properties
		for(VaonDeviceBatteryCell *subview in batteryHStackView.subviews){

			if(!subview.device) {
				for(BCBatteryDevice *device in connectedBluetoothDevices) {
					if([device.name isEqual:subview.deviceName]) {
						subview.device = device;
					}
				}
			}

			//checks if the device is not connected anymore
			if((![connectedBluetoothDevices containsObject:subview.device] && ![subview.device isConnected])){
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
				if([subview.device isConnected]){
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
						stockHidden = FALSE;
					}
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
		switcherContentView = self;
		if(![selectedModule isEqual:@"none"]){
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
							delayedFadeInTimer = [NSTimer scheduledTimerWithTimeInterval:fadeInDelay target:self selector:@selector(delayedFadeViewIn) userInfo:nil repeats:NO];
					} else {
						fadeViewIn(vaonView, 0.4);
					}
				} else {
					if(stockHidden){
						if(enableDelay) {
							delayedFadeInTimer = [NSTimer scheduledTimerWithTimeInterval:fadeInDelay target:self selector:@selector(delayedFadeViewIn) userInfo:nil repeats:NO];
						} else {
							fadeViewIn(vaonView, 0.4);
						}
					}
				}
			} 
		}

	}

	%new
	-(void)delayedFadeViewIn {
		fadeViewIn(vaonView, 0.4);
		[delayedFadeInTimer invalidate];
		delayedFadeInTimer = nil;
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




%hook SBAppSwitcherSettings

	//track the current switcher style so the battery view places itself correctly
	-(void)setSwitcherStyle: (long long)arg1 {
		%orig;
		currentSwitcherStyle = self.switcherStyle;
	}
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
		@"customChargingColor": @"#33b5e5"
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
			vaonOpenFrontApp = [currentAppDisplayID copy];
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
}

%ctor {
	prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
	updateSettings();

	//keep UIDevice.orientation populated so landscape detection works in the switcher
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

	//grid app switcher is the assumed default; the SBAppSwitcherSettings hook keeps this
	//in sync with the actual style so the battery view places itself correctly
	currentSwitcherStyle = 2;

	//Vaon targets iOS 16; do nothing on older versions
	if(isEnabled && kCFCoreFoundationVersionNumber > 1900){
		%init;
		%init(iOS16SwitcherCoordinator);
		%init(iOS16FloatingDock);

		//only hook SquidGesture Pro's action class if it is actually installed
		if(NSClassFromString(@"SFActivityAction")){
			%init(VaonSquidGestureCompat);
		}
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