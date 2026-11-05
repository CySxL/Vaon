#include "VaonRootListController.h"
#import <Preferences/PSSliderTableCell.h>
#import <objc/runtime.h>
#import <notify.h>

#if THEOS_PACKAGE_SCHEME_ROOTHIDE
#import <roothide.h>
#endif

//maybe check if the user is going back to the previous value a specifier was at before prompting the alert to repsring
//make a new NSUserDefauls
NSUserDefaults *prefs;

//a switch nobody has touched is unset, and reads as its plist default rather than as off
static BOOL vaonPrefBool(NSString *key, BOOL fallback) {
	id value = [prefs objectForKey:key];
	return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : fallback;
}

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
        return NO;
    }
}

//the tweak normalises the same store on its own side; the two binaries share no header, so this is
//deliberately a second copy rather than a shared file for one function. records without an identifier
//string are dropped, since nothing here can match or pin them
static NSArray *vaonNormalizedKnownDevices(id stored) {
	NSMutableArray *devices = [NSMutableArray array];
	if(![stored isKindOfClass:[NSArray class]]) return devices;
	for(id entry in (NSArray *)stored){
		if(![entry isKindOfClass:[NSDictionary class]]) continue;
		NSDictionary *raw = entry;
		NSMutableDictionary *record = [NSMutableDictionary dictionary];
		for(NSString *field in @[@"identifier", @"name", @"source", @"customGlyph"]){
			if([raw[field] isKindOfClass:[NSString class]]) record[field] = raw[field];
		}
		for(NSString *field in @[@"productIdentifier", @"lastPercentage", @"lastSeen"]){
			if([raw[field] isKindOfClass:[NSNumber class]]) record[field] = raw[field];
		}
		if([raw[@"glyph"] isKindOfClass:[NSData class]]) record[@"glyph"] = raw[@"glyph"];
		if(!record[@"identifier"]) continue;
		[devices addObject:record];
	}
	return devices;
}

static NSArray *vaonNormalizedPins(id stored) {
	NSMutableArray *pins = [NSMutableArray array];
	if(![stored isKindOfClass:[NSArray class]]) return pins;
	for(id pid in (NSArray *)stored){
		if([pid isKindOfClass:[NSString class]]) [pins addObject:pid];
	}
	return pins;
}

//the tweak rebuilds its view from the stored values on the next switcher open after this
static void vaonPostChange(void) {
	notify_post("com.atar13.vaonprefs/changed");
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

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PACKAGE_SCHEME "roothide"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
#define PACKAGE_SCHEME "rootless"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTFUL)
#define PACKAGE_SCHEME "rootful"
#else
#error theos defined no package scheme
#endif

static const CGFloat kVaonIconSide = 80.0;
static const CGFloat kVaonHeaderGap = 16.0;
//"Vaon" fits beside the icon at 34 pt on any phone
static const CGFloat kVaonNameSize = 34.0;
static const CGFloat kVaonVersionSize = 15.0;
static const CGFloat kVaonSchemeSize = 13.0;
static const CGFloat kVaonNameToVersion = 24.0;
static const CGFloat kVaonVersionToScheme = 19.0;

static UIFont *vaonHeaderNameFont(CGFloat size) {
	UIFontDescriptor *bold = [[UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleLargeTitle] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
	return [UIFont fontWithDescriptor:bold size:size];
}

//the name's baseline against the icon's middle, with the block centred on it, so a larger name grows upward only
static CGFloat vaonNameBaselineOffset(CGFloat scale) {
	UIFont *name = vaonHeaderNameFont(kVaonNameSize * scale);
	UIFont *scheme = [UIFont systemFontOfSize:kVaonSchemeSize * scale];
	CGFloat height = name.ascender + (kVaonNameToVersion + kVaonVersionToScheme) * scale - scheme.descender;
	return name.ascender - height / 2.0;
}

static const CGFloat kVaonAvatarSide = 38.0;

//the row indents its text by the width of its image, so a symbol takes the same square as the avatar
static UIImage *vaonSymbol(NSString *name, CGFloat side) {
	UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightMedium];
	UIImage *symbol = [UIImage systemImageNamed:name withConfiguration:configuration] ?: [UIImage systemImageNamed:@"link" withConfiguration:configuration];
	if(!symbol) return nil;
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
	UIImage *padded = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
		[symbol drawInRect:CGRectMake((side - symbol.size.width) / 2.0, (side - symbol.size.height) / 2.0, symbol.size.width, symbol.size.height)];
	}];
	return [padded imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface VaonCreditCell : PSTableCell
@end

//a row carrying vaonBranch hangs off the row above it: a line from that row's avatar bends into it, and
//the row above, carrying vaonBranchBelow, drops its separator and draws the top of the line
@implementation VaonCreditCell {
	UIImageView *_avatarView;
	CAShapeLayer *_branch;
}

	-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
		self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier];
		if(!self) return nil;
		self.detailTextLabel.text = [specifier propertyForKey:@"subtitle"] ?: @"";
		self.detailTextLabel.textColor = [UIColor systemGrayColor];
		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		BOOL branch = [[specifier propertyForKey:@"vaonBranch"] isEqual:@YES];
		if(branch || [[specifier propertyForKey:@"vaonBranchBelow"] isEqual:@YES]){
			_branch = [CAShapeLayer layer];
			_branch.fillColor = nil;
			_branch.lineWidth = 1.5;
			_branch.lineCap = kCALineCapRound;
			[self.contentView.layer addSublayer:_branch];
		}
		if(branch){
			//an empty slot as wide as the avatar, so the text lines up with the name above
			UIGraphicsBeginImageContextWithOptions(CGSizeMake(kVaonAvatarSide, 16.0), NO, [UIScreen mainScreen].scale);
			[specifier setProperty:UIGraphicsGetImageFromCurrentImageContext() forKey:@"iconImage"];
			UIGraphicsEndImageContext();
			UIImageSymbolConfiguration *small = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
			NSTextAttachment *code = [[NSTextAttachment alloc] init];
			code.image = [[UIImage systemImageNamed:@"chevron.left.forwardslash.chevron.right" withConfiguration:small] imageWithTintColor:[UIColor linkColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
			NSMutableAttributedString *title = [[NSMutableAttributedString alloc] init];
			if(code.image) [title appendAttributedString:[NSAttributedString attributedStringWithAttachment:code]];
			[title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:specifier.name ?: @""]
				attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13.0], NSForegroundColorAttributeName: [UIColor linkColor]}]];
			self.textLabel.attributedText = title;
			//nil rather than empty, so the subtitle style centres the one line
			self.detailTextLabel.text = nil;
			return self;
		}
		UIImage *avatar = [specifier propertyForKey:@"vaonAvatar"];
		if(![avatar isKindOfClass:[UIImage class]]){
			self.imageView.tintColor = [UIColor secondaryLabelColor];
			return self;
		}
		//an empty image of the right size, so the row lays out before the avatar is drawn into it
		UIGraphicsBeginImageContextWithOptions(CGSizeMake(kVaonAvatarSide, kVaonAvatarSide), NO, [UIScreen mainScreen].scale);
		[specifier setProperty:UIGraphicsGetImageFromCurrentImageContext() forKey:@"iconImage"];
		UIGraphicsEndImageContext();
		_avatarView = [[UIImageView alloc] initWithFrame:self.imageView.bounds];
		_avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_avatarView.contentMode = UIViewContentModeScaleAspectFill;
		_avatarView.clipsToBounds = YES;
		_avatarView.layer.cornerRadius = kVaonAvatarSide * 0.5;
		_avatarView.layer.minificationFilter = kCAFilterTrilinear;
		_avatarView.image = avatar;
		[self.imageView addSubview:_avatarView];
		return self;
	}

	-(void)layoutSubviews {
		[super layoutSubviews];
		if(!_branch) return;
		BOOL branch = [[self.specifier propertyForKey:@"vaonBranch"] isEqual:@YES];
		if(!branch){
			for(UIView *view in self.subviews){
				if([NSStringFromClass([view class]) hasSuffix:@"SeparatorView"]) view.hidden = YES;
			}
		}
		_branch.strokeColor = [[UIColor systemGray3Color] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
		CGRect slot = [self.contentView convertRect:self.imageView.bounds fromView:self.imageView];
		CGFloat x = round(CGRectGetMidX(slot));
		UIBezierPath *path = [UIBezierPath bezierPath];
		if(branch){
			CGFloat y = round(CGRectGetMidY(slot)), r = 6.0;
			[path moveToPoint:CGPointMake(x, 0)];
			[path addLineToPoint:CGPointMake(x, y - r)];
			[path addQuadCurveToPoint:CGPointMake(x + r, y) controlPoint:CGPointMake(x, y)];
			[path addLineToPoint:CGPointMake(CGRectGetMaxX(slot), y)];
		} else {
			[path moveToPoint:CGPointMake(x, CGRectGetMaxY(slot) + 3.0)];
			[path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.contentView.bounds))];
		}
		_branch.path = path.CGPath;
	}

	-(void)traitCollectionDidChange:(UITraitCollection *)previous {
		[super traitCollectionDidChange:previous];
		[self setNeedsLayout];
	}

@end

@interface VaonHeaderCell : PSTableCell
@end

@implementation VaonHeaderCell {
	UILabel *_name;
	UILabel *_version;
	UILabel *_scheme;
	UIStackView *_text;
	NSLayoutConstraint *_nameBaseline;
	CGFloat _scale;
}

	-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
		self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier];
		if(!self) return nil;

		UIImage *image = [UIImage imageNamed:@"images/vaon/vaonHeader" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
		UIImageView *icon = [[UIImageView alloc] initWithImage:image];
		icon.translatesAutoresizingMaskIntoConstraints = NO;
		icon.clipsToBounds = YES;
		icon.layer.cornerCurve = kCACornerCurveContinuous;
		icon.layer.cornerRadius = kVaonIconSide * 0.225;
		[self.contentView addSubview:icon];

		_name = [[UILabel alloc] init];
		_name.text = @"Vaon";
		//the icon's moss green, and its peach background in dark mode, where the green is 2.9:1 on black
		_name.textColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
			return traits.userInterfaceStyle == UIUserInterfaceStyleDark
				? [UIColor colorWithRed:0xfa / 255.0 green:0xcb / 255.0 blue:0xc6 / 255.0 alpha:1.0]
				: [UIColor colorWithRed:0x46 / 255.0 green:0x5c / 255.0 blue:0x47 / 255.0 alpha:1.0];
		}];

		_version = [[UILabel alloc] init];
		_version.text = @"Version " PACKAGE_VERSION;
		_version.textColor = [UIColor systemGrayColor];

		_scheme = [[UILabel alloc] init];
		_scheme.text = @PACKAGE_SCHEME.capitalizedString;
		_scheme.textColor = [UIColor systemGrayColor];

		//baseline to baseline, so the large name's own leading does not push the two lines under it away
		_text = [[UIStackView alloc] initWithArrangedSubviews:@[_name, _version, _scheme]];
		_text.axis = UILayoutConstraintAxisVertical;
		_text.alignment = UIStackViewAlignmentLeading;
		_text.baselineRelativeArrangement = YES;
		_text.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:_text];
		_nameBaseline = [_name.firstBaselineAnchor constraintEqualToAnchor:icon.centerYAnchor];
		[self applyTextScale:1.0];

		//icon and text centred as one block, never past the leading margin
		UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
		UILayoutGuide *block = [[UILayoutGuide alloc] init];
		[self.contentView addLayoutGuide:block];
		NSLayoutConstraint *centred = [block.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor];
		centred.priority = UILayoutPriorityDefaultHigh;
		[NSLayoutConstraint activateConstraints:@[
			[icon.widthAnchor constraintEqualToConstant:kVaonIconSide],
			[icon.heightAnchor constraintEqualToConstant:kVaonIconSide],
			[block.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor],
			[block.trailingAnchor constraintEqualToAnchor:_text.trailingAnchor],
			[icon.leadingAnchor constraintGreaterThanOrEqualToAnchor:margins.leadingAnchor],
			centred,
			[icon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
			[_text.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:kVaonHeaderGap],
			_nameBaseline
		]];
		return self;
	}

	//fonts and spacing scale together so the three lines keep their proportions; the icon never scales
	-(void)applyTextScale:(CGFloat)scale {
		if(scale == _scale) return;
		_scale = scale;
		_name.font = vaonHeaderNameFont(kVaonNameSize * scale);
		_version.font = [UIFont systemFontOfSize:kVaonVersionSize * scale];
		_scheme.font = [UIFont systemFontOfSize:kVaonSchemeSize * scale];
		[_text setCustomSpacing:kVaonNameToVersion * scale afterView:_name];
		[_text setCustomSpacing:kVaonVersionToScheme * scale afterView:_version];
		_nameBaseline.constant = vaonNameBaselineOffset(scale);
	}

	//full size wherever the name fits beside the icon, otherwise the whole block shrinks by the overflow
	-(void)layoutSubviews {
		CGFloat available = CGRectGetWidth(self.contentView.layoutMarginsGuide.layoutFrame) - kVaonIconSide - kVaonHeaderGap;
		CGFloat natural = [_name.text sizeWithAttributes:@{NSFontAttributeName: vaonHeaderNameFont(kVaonNameSize)}].width;
		[self applyTextScale:(available > 0 && natural > available) ? available / natural : 1.0];
		[super layoutSubviews];
	}

	//the row is the page's heading, not a setting: no separator, no grouped background, no selection
	-(void)setSeparatorStyle:(UITableViewCellSeparatorStyle)style {
		[super setSeparatorStyle:UITableViewCellSeparatorStyleNone];
	}

	-(void)setBackgroundColor:(UIColor *)color {
		[super setBackgroundColor:[UIColor clearColor]];
	}

	-(UITableViewCellSelectionStyle)selectionStyle {
		return UITableViewCellSelectionStyleNone;
	}

@end

static NSUserDefaults *vaonStore(void) {
	static NSUserDefaults *store;
	if(!store) store = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
	return store;
}

//a switch or mode as stored, or its plist default when it has never been set
static id vaonControlValue(PSSpecifier *control) {
	id value = [vaonStore() objectForKey:[control propertyForKey:@"key"]];
	return value ?: [control propertyForKey:@"default"];
}

//gateValue names the mode that shows the row; without one the row follows a switch
static BOOL vaonGateOpen(PSSpecifier *row, id value) {
	id want = [row propertyForKey:@"gateValue"];
	if([want isKindOfClass:[NSString class]]) return [value isKindOfClass:[NSString class]] && [value isEqualToString:want];
	return [value isKindOfClass:[NSNumber class]] && [value boolValue];
}

//a double tap on the row types an exact value. the stock value label stays, so nothing is drawn here
@interface VaonSliderCell : PSSliderTableCell
@end

@implementation VaonSliderCell {
	BOOL _prepared;
}

	-(UISlider *)slider {
		return [self.control isKindOfClass:[UISlider class]] ? (UISlider *)self.control : nil;
	}

	//the control does not exist yet when the cell is built, so the setup waits for the first layout
	-(void)layoutSubviews {
		[super layoutSubviews];
		[self dropForceTouch];
		if(_prepared || ![self slider]) return;
		_prepared = YES;
		UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(enterValue)];
		doubleTap.numberOfTapsRequired = 2;
		[self.contentView addGestureRecognizer:doubleTap];
	}

	//the slider stays continuous; a typed value keeps one decimal and drops a trailing .0
	-(NSString *)format:(double)value {
		double tenths = round(value * 10) / 10;
		return tenths == round(tenths) ? [NSString stringWithFormat:@"%ld", lround(tenths)] : [NSString stringWithFormat:@"%.1f", tenths];
	}

	//slider rows have no title, so the alert takes the switch or group label above the row
	-(NSString *)rowTitle {
		PSListController *controller = self.specifier.target;
		NSInteger index = [controller indexOfSpecifier:self.specifier];
		if(index != NSNotFound && index > 0){
			NSString *name = [[controller specifierAtIndex:index - 1] name];
			if([name isKindOfClass:[NSString class]] && name.length) return name;
		}
		return @"Value";
	}

	-(void)enterValue {
		UISlider *slider = [self slider];
		PSListController *controller = self.specifier.target;
		if(!slider || ![controller isKindOfClass:[PSListController class]]) return;
		double low = slider.minimumValue, high = slider.maximumValue;
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self rowTitle]
			message:[NSString stringWithFormat:@"%@ to %@.", [self format:low], [self format:high]]
			preferredStyle:UIAlertControllerStyleAlert];
		[alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
			//the number pad has no minus sign, and seven of these sliders go below zero
			field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
			field.text = [self format:slider.value];
			field.clearButtonMode = UITextFieldViewModeAlways;
		}];
		__weak VaonSliderCell *weakSelf = self;
		__weak UIAlertController *weakAlert = alert;
		[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
		[alert addAction:[UIAlertAction actionWithTitle:@"Set" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			VaonSliderCell *cell = weakSelf;
			NSString *text = [weakAlert.textFields.firstObject.text stringByReplacingOccurrencesOfString:@"," withString:@"."];
			NSScanner *scanner = [NSScanner scannerWithString:text ?: @""];
			double typed = 0;
			if(!cell || ![scanner scanDouble:&typed] || !scanner.isAtEnd) return;
			double value = MIN(MAX(round(typed * 10) / 10, low), high);
			PSListController *target = cell.specifier.target;
			if(![target isKindOfClass:[PSListController class]]) return;
			[target setPreferenceValue:@(value) specifier:cell.specifier];
			[target reloadSpecifier:cell.specifier animated:NO];
		}]];
		[controller presentViewController:alert animated:YES completion:nil];
	}

	//a force touch recogniser another tweak adds to sliders can strand in Changed after a pull-down mid drag
	//and block every gesture under the table; only our own cells are touched
	-(void)dropForceTouch {
		static Class stuck = nil;
		static dispatch_once_t once;
		dispatch_once(&once, ^{ stuck = objc_getClass("CSPForceTouchGestureRecognizer"); });
		UISlider *slider = [self slider];
		if(!stuck || !slider) return;
		UIGestureRecognizer *found = nil;
		for(UIGestureRecognizer *gesture in slider.gestureRecognizers){
			if([gesture isKindOfClass:stuck]){ found = gesture; break; }
		}
		if(found) [slider removeGestureRecognizer:found];
	}

@end

@implementation VaonGatedListController {
	//every gated row in plist order, on the page or not
	NSArray *_gatedRows;
}

	-(void)prepareSpecifier:(PSSpecifier *)specifier {
	}

	//a gated row sits directly under the switch or segment it follows
	-(NSMutableArray *)gatedSpecifiersFromPlistName:(NSString *)name {
		NSMutableArray *all = [[self loadSpecifiersFromPlistName:name target:self] mutableCopy];
		NSMutableArray *gated = [NSMutableArray array];
		NSMutableArray *shut = [NSMutableArray array];
		NSMutableDictionary *controls = [NSMutableDictionary dictionary];
		//before the shut rows leave the array, so a row inserted later is built with it too
		for(PSSpecifier *s in all){
			if(s.cellType == PSSliderCell) [s setProperty:[VaonSliderCell class] forKey:@"cellClass"];
			[self prepareSpecifier:s];
			NSString *key = [s propertyForKey:@"key"];
			if([key isKindOfClass:[NSString class]]) controls[key] = s;
			NSString *gate = [s propertyForKey:@"gateKey"];
			if(![gate isKindOfClass:[NSString class]]) continue;
			[gated addObject:s];
			PSSpecifier *control = controls[gate];
			if(!control || !vaonGateOpen(s, vaonControlValue(control))) [shut addObject:s];
		}
		[all removeObjectsInArray:shut];
		_gatedRows = gated;
		return all;
	}

	-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
		[super setPreferenceValue:value specifier:specifier];
		vaonPostChange();
		NSString *key = [specifier propertyForKey:@"key"];
		if(![key isKindOfClass:[NSString class]]) return;
		PSSpecifier *previous = specifier;
		for(PSSpecifier *row in _gatedRows){
			if(![[row propertyForKey:@"gateKey"] isEqual:key]) continue;
			BOOL shown = ([self indexOfSpecifier:row] != NSNotFound);
			if(vaonGateOpen(row, value)){
				if(!shown) [self insertSpecifier:row afterSpecifier:previous animated:YES];
				previous = row;
			} else if(shown){
				[self removeSpecifier:row animated:YES];
			}
		}
	}

@end

//Alderis stored #RRGGBB at full alpha and #AARRGGBB below it, and the tweak reads both, so the picker keeps that format
static BOOL vaonParseHex(id value, CGFloat rgba[4]) {
	if(![value isKindOfClass:[NSString class]]) return NO;
	NSString *digits = [value hasPrefix:@"#"] ? [value substringFromIndex:1] : value;
	if(digits.length != 6 && digits.length != 8) return NO;
	NSScanner *scanner = [NSScanner scannerWithString:digits];
	unsigned long long v = 0;
	if(![scanner scanHexLongLong:&v] || !scanner.isAtEnd) return NO;
	rgba[0] = ((v >> 16) & 0xFF) / 255.0;
	rgba[1] = ((v >> 8) & 0xFF) / 255.0;
	rgba[2] = (v & 0xFF) / 255.0;
	rgba[3] = (digits.length == 8) ? ((v >> 24) & 0xFF) / 255.0 : 1.0;
	return YES;
}

static NSString *vaonHexString(const CGFloat rgba[4]) {
	long c[4];
	for(int i = 0; i < 4; i++) c[i] = lround(fmin(fmax(rgba[i], 0.0), 1.0) * 255.0);
	if(c[3] == 255) return [NSString stringWithFormat:@"#%02lx%02lx%02lx", c[0], c[1], c[2]];
	return [NSString stringWithFormat:@"#%02lx%02lx%02lx%02lx", c[3], c[0], c[1], c[2]];
}

static UIColor *vaonRowColor(PSSpecifier *row) {
	CGFloat rgba[4];
	if(!vaonParseHex([vaonStore() objectForKey:[row propertyForKey:@"colorKey"]], rgba) && !vaonParseHex([row propertyForKey:@"default"], rgba)) return nil;
	return [UIColor colorWithRed:rgba[0] green:rgba[1] blue:rgba[2] alpha:rgba[3]];
}

//the row icon, at the size Settings gives its own
static UIImage *vaonSwatch(UIColor *color) {
	CGFloat side = 29.0;
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
	return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
		UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5, 0.5, side - 1.0, side - 1.0) cornerRadius:side * 0.225];
		[(color ?: [UIColor clearColor]) setFill];
		[shape fill];
		[[UIColor colorWithWhite:0.5 alpha:0.35] setStroke];
		[shape stroke];
	}];
}

@implementation VaonColorListController {
	PSSpecifier *_picking;
}

	-(void)prepareSpecifier:(PSSpecifier *)specifier {
		if([[specifier propertyForKey:@"colorKey"] isKindOfClass:[NSString class]]){
			[specifier setProperty:vaonSwatch(vaonRowColor(specifier)) forKey:@"iconImage"];
		}
	}

	-(PSSpecifier *)colorSpecifierAtIndexPath:(NSIndexPath *)indexPath {
		PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
		return [[specifier propertyForKey:@"colorKey"] isKindOfClass:[NSString class]] ? specifier : nil;
	}

	-(NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
		if([self colorSpecifierAtIndexPath:indexPath]) return indexPath;
		if([PSListController instancesRespondToSelector:_cmd]) return [super tableView:tableView willSelectRowAtIndexPath:indexPath];
		return indexPath;
	}

	-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
		PSSpecifier *specifier = [self colorSpecifierAtIndexPath:indexPath];
		if(!specifier){
			[super tableView:tableView didSelectRowAtIndexPath:indexPath];
			return;
		}
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		_picking = specifier;
		UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
		picker.title = specifier.name;
		picker.supportsAlpha = YES;
		picker.selectedColor = vaonRowColor(specifier) ?: [UIColor whiteColor];
		picker.delegate = self;
		[self presentViewController:picker animated:YES completion:nil];
	}

	-(void)savePickedColor:(UIColor *)color {
		NSString *key = [_picking propertyForKey:@"colorKey"];
		if(![key isKindOfClass:[NSString class]] || !color) return;
		CGFloat rgba[4] = {0, 0, 0, 0};
		if(![color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]]) return;
		[vaonStore() setObject:vaonHexString(rgba) forKey:key];
		vaonPostChange();
		[_picking setProperty:vaonSwatch(vaonRowColor(_picking)) forKey:@"iconImage"];
		[self reloadSpecifier:_picking animated:NO];
	}

	-(void)colorPickerViewController:(UIColorPickerViewController *)picker didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
		if(!continuously) [self savePickedColor:color];
	}

	-(void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker {
		[self savePickedColor:picker.selectedColor];
		_picking = nil;
	}

@end

@implementation BatteryColorPreferenceController

	-(NSArray *)specifiers {
		if (!_specifiers) {
			_specifiers = [self gatedSpecifiersFromPlistName:@"BatteryColor"];
		}

		return _specifiers;
	}
	-(void)viewDidLoad {
		[super viewDidLoad];
		self.title = @"Cell Color Configuration";
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
@end


@implementation BatteryPreferenceController

	-(NSArray *)specifiers {
		if (!_specifiers) {
			_specifiers = [self gatedSpecifiersFromPlistName:@"Battery"];
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
@end

//the two sets of landscape sliders, each shown only while its own switch is on
static NSArray *vaonLandscapeOffsetIDs(void) {
	return @[@"landscapeHOffsetHeader", @"landscapeHorizontalOffset", @"landscapeVOffsetHeader", @"landscapeVerticalOffset"];
}

static NSArray *vaonLandscapeModuleIDs(void) {
	return @[@"landscapeModuleSideHeader", @"landscapeModuleSide", @"landscapeModuleHOffsetHeader", @"landscapeModuleHorizontalOffset", @"landscapeModuleVOffsetHeader", @"landscapeModuleVerticalOffset"];
}

//everything Hide in Landscape takes off the page
static NSArray *vaonLandscapeIDs(void) {
	NSMutableArray *ids = [NSMutableArray arrayWithObjects:@"landscapeFullWidthHeader", @"landscapeOffsetEnabled", nil];
	[ids addObjectsFromArray:vaonLandscapeOffsetIDs()];
	[ids addObjectsFromArray:@[@"landscapeModuleHeader", @"landscapeModuleEnabled"]];
	[ids addObjectsFromArray:vaonLandscapeModuleIDs()];
	return ids;
}

@implementation VaonRootListController {
	//the pagination options that only make sense when page dots are shown; stashed so they can be
	//pulled out and re-inserted as the Show Page Dots switch flips
	NSArray *_swipeDependentSpecifiers;
	//everything under Hide in Landscape, in page order
	NSArray *_landscapeSpecifiers;
}
	//-(id)readPreferenceValue:(PSSpecifier*)specifier; use this to get the current modele selected and make a method that returns it and passes it into the pslinkcell in root.plist
	-(id)init {
		prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
		//the module's offsets start from the landscape ones it was tuned with, copied once
		for(NSArray *pair in @[@[@"landscapeHorizontalOffset", @"landscapeModuleHorizontalOffset"], @[@"landscapeVerticalOffset", @"landscapeModuleVerticalOffset"]]){
			id old = [prefs objectForKey:pair[0]];
			if(![prefs objectForKey:pair[1]] && [old isKindOfClass:[NSNumber class]]) [prefs setObject:old forKey:pair[1]];
		}
		//the two landscape switches are exclusive, and with both on the tweak already uses the module
		if(vaonPrefBool(@"landscapeOffsetEnabled", NO) && vaonPrefBool(@"landscapeModuleEnabled", NO)) [prefs setBool:NO forKey:@"landscapeOffsetEnabled"];
		return [super init];
	}

	-(NSArray *)specifiers {
		if (!_specifiers) {
			NSMutableArray *all = [self gatedSpecifiersFromPlistName:@"Root"];
			//collect the dots-dependent options in plist order, then drop them if page dots are off
			NSMutableArray *deps = [NSMutableArray array];
			NSMutableArray *landDeps = [NSMutableArray array];
			for(PSSpecifier *s in all){
				NSString *sid = [s identifier];
				if([sid isEqualToString:@"verticalPageDots"] || [sid isEqualToString:@"pageDotsOnlyWhileSwiping"]){
					[deps addObject:s];
				}
				if([vaonLandscapeIDs() containsObject:sid]) [landDeps addObject:s];
			}
			_swipeDependentSpecifiers = deps;
			_landscapeSpecifiers = landDeps;
			if(!vaonPrefBool(@"showPageDots", YES)){
				[all removeObjectsInArray:deps];
			}
			NSArray *visible = [self visibleLandscapeSpecifiers:nil];
			for(PSSpecifier *s in landDeps){ if(![visible containsObject:s]) [all removeObject:s]; }
			//Root.plist opens with a group, so the header gets a section of its own
			PSSpecifier *header = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:NULL get:NULL detail:nil cell:PSStaticTextCell edit:nil];
			[header setProperty:[VaonHeaderCell class] forKey:@"cellClass"];
			[header setProperty:@142 forKey:@"height"];
			[all insertObject:header atIndex:0];
			[self addCreditsTo:all];
			_specifiers = all;
		}

		return _specifiers;
	}

	//upstream's two authors keep their own links and pictures; the fork's row comes last
	-(void)addCreditsTo:(NSMutableArray *)specifiers {
		PSSpecifier *credits = [PSSpecifier emptyGroupSpecifier];
		[credits setProperty:@"Credits" forKey:@"label"];
		[credits setProperty:@"© CySxL 2026" forKey:@"footerText"];
		[specifiers addObject:credits];
		//name, subtitle, action, picture; a row with no picture is a branch of the row above it
		NSArray *rows = @[
			@[@"Anthony Tarbinian", @"Original Developer", NSStringFromSelector(@selector(twitter)), @"images/twitter/twitterIcon"],
			@[@"Source Code", @"", NSStringFromSelector(@selector(github)), @""],
			@[@"SingleKeycap", @"@singlekeycap", NSStringFromSelector(@selector(twitterKeycap)), @"images/twitter/twitterIconKeycap"],
			@[@"CySxL", @"Maintainer · iOS 16 Port", NSStringFromSelector(@selector(githubCySxL)), @"avatar"]
		];
		PSSpecifier *previous = nil;
		for(NSArray *row in rows){
			PSSpecifier *credit = [PSSpecifier preferenceSpecifierNamed:row[0] target:self set:NULL get:NULL detail:nil cell:PSLinkCell edit:nil];
			[credit setProperty:[VaonCreditCell class] forKey:@"cellClass"];
			[credit setProperty:row[1] forKey:@"subtitle"];
			if([row[3] length] == 0){
				[credit setProperty:@YES forKey:@"vaonBranch"];
				[credit setProperty:@34 forKey:@"height"];
				[previous setProperty:@YES forKey:@"vaonBranchBelow"];
			} else {
				UIImage *avatar = [UIImage imageNamed:row[3] inBundle:[NSBundle bundleForClass:[self class]] withConfiguration:nil];
				if(avatar) [credit setProperty:avatar forKey:@"vaonAvatar"];
				else [credit setProperty:vaonSymbol(@"chevron.left.forwardslash.chevron.right", kVaonAvatarSide) forKey:@"iconImage"];
			}
			credit->action = NSSelectorFromString(row[2]);
			[specifiers addObject:credit];
			previous = credit;
		}
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

	//the landscape controls that belong on the page: none while Hide in Landscape is on, and each set of
	//sliders only while its switch is. values carries a switch that has just changed
	-(NSArray *)visibleLandscapeSpecifiers:(NSDictionary *)values {
		BOOL (^on)(NSString *) = ^BOOL(NSString *key){
			id v = values[key];
			return v ? [v boolValue] : vaonPrefBool(key, NO);
		};
		if(on(@"hideInLandscape")) return @[];
		NSMutableArray *visible = [NSMutableArray array];
		for(PSSpecifier *s in _landscapeSpecifiers){
			NSString *sid = [s identifier];
			if([vaonLandscapeOffsetIDs() containsObject:sid] && !on(@"landscapeOffsetEnabled")) continue;
			if([vaonLandscapeModuleIDs() containsObject:sid] && !on(@"landscapeModuleEnabled")) continue;
			[visible addObject:s];
		}
		return visible;
	}

	//bring the page in step with the switches, touching only the rows that change
	-(void)refreshLandscapeSpecifiers:(NSDictionary *)values {
		NSArray *visible = [self visibleLandscapeSpecifiers:values];
		for(PSSpecifier *s in _landscapeSpecifiers){
			if(![visible containsObject:s] && [self indexOfSpecifier:s] != NSNotFound) [self removeSpecifier:s animated:YES];
		}
		PSSpecifier *previous = [self specifierForID:@"hideInLandscape"];
		for(PSSpecifier *s in visible){
			if([self indexOfSpecifier:s] == NSNotFound) [self insertSpecifier:s afterSpecifier:previous animated:YES];
			previous = s;
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


	-(void)github{
		[[UIApplication sharedApplication] 
			openURL:[NSURL URLWithString:@"https://github.com/atar13/Vaon"] 
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
		NSString *key = specifier.properties[@"key"];
		if(value && [@[@"hideInLandscape", @"landscapeOffsetEnabled", @"landscapeModuleEnabled"] containsObject:key]){
			NSMutableDictionary *changed = [NSMutableDictionary dictionaryWithObject:value forKey:key];
			NSString *other = @{@"landscapeOffsetEnabled": @"landscapeModuleEnabled", @"landscapeModuleEnabled": @"landscapeOffsetEnabled"}[key];
			PSSpecifier *otherSpecifier = other ? [self specifierForID:other] : nil;
			if(otherSpecifier && [value boolValue] && vaonPrefBool(other, NO)){
				[super setPreferenceValue:@NO specifier:otherSpecifier];
				[self reloadSpecifier:otherSpecifier animated:YES];
				changed[other] = @NO;
			}
			[self refreshLandscapeSpecifiers:changed];
		}
		//the module choice decides which views exist, so it still asks for a respring
		if([specifier.properties[@"key"] isEqualToString:@"moduleSelection"]){
			[self prefsChangeAlert];
		}
	}



@end


@implementation VaonPinnedDevicesController {
	NSMutableArray *_knownDevices;
	NSMutableArray *_pinnedIds;
	UITableView *_tableView;
	NSUserDefaults *_store;
}

	-(NSUserDefaults *)store {
		if(!_store) _store = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
		return _store;
	}

	-(void)loadModel {
		NSUserDefaults *d = [self store];
		NSArray *raw = vaonNormalizedKnownDevices([d objectForKey:@"knownDevices"]);
		//one row per name (AirPods report left/right under the same name); map every id to its representative
		NSMutableArray *collapsed = [NSMutableArray array];
		NSMutableDictionary *nameToRep = [NSMutableDictionary dictionary];
		NSMutableDictionary *idToRep = [NSMutableDictionary dictionary];
		for(NSDictionary *dev in raw){
			NSString *nm = dev[@"name"];
			NSString *ident = dev[@"identifier"];
			NSString *rep = nm.length ? nameToRep[nm] : nil;
			if(rep == nil){
				rep = ident;
				if(nm.length) nameToRep[nm] = ident;
				[collapsed addObject:dev];
			}
			idToRep[ident] = rep;
		}
		_knownDevices = collapsed;
		NSArray *rawPinned = vaonNormalizedPins([d objectForKey:@"pinnedDeviceIdentifiers"]);
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
		vaonPostChange();
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

	-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

	-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
		if(section == 2) return 1;
		if(_knownDevices.count == 0) return (section == 0) ? 1 : 0;
		return (section == 0) ? _pinnedIds.count : [self availableDevices].count;
	}

	-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
		if(section == 2) return @"Automatic Removal";
		return (section == 0) ? @"Pinned (drag to reorder)" : @"Available Devices";
	}

	-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
		if(section == 2) return @"Removes devices that have not connected for 90 days. Pinned devices are never removed. Respring to apply.";
		return (section == 1) ? @"Pinned devices stay shown after respring, even when disconnected. Respring to apply." : nil;
	}

	-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
		if(indexPath.section == 2){
			UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"vaonExpiryCell"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.textLabel.text = @"Remove Unseen Devices";
			UISwitch *sw = [[UISwitch alloc] init];
			//unset means on, which is what the tweak registers
			id stored = [[self store] objectForKey:@"expireUnseenDevices"];
			sw.on = [stored isKindOfClass:[NSNumber class]] ? [stored boolValue] : YES;
			[sw addTarget:self action:@selector(expirySwitchChanged:) forControlEvents:UIControlEventValueChanged];
			cell.accessoryView = sw;
			cell.editingAccessoryView = sw;
			return cell;
		}
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

	-(void)expirySwitchChanged:(UISwitch *)sw {
		NSUserDefaults *d = [self store];
		[d setBool:sw.on forKey:@"expireUnseenDevices"];
		[d synchronize];
		vaonPostChange();
	}

	-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
		//available devices can be deleted from the store to declutter; pinned rows only reorder
		return (indexPath.section == 1 && _knownDevices.count > 0) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
	}

	-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
		//both sections must be editable so section 0 shows the reorder control; editingStyle differentiates
		return (indexPath.section != 2 && _knownDevices.count > 0);
	}

	-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
		if(editingStyle != UITableViewCellEditingStyleDelete) return;
		NSDictionary *dev = [self deviceAtIndexPath:indexPath];
		NSString *ident = dev[@"identifier"];
		NSString *nm = dev[@"name"];
		if(!ident) return;
		NSUserDefaults *d = [self store];
		//remove every stored record sharing this name (or identifier), plus any pins referencing them
		NSArray *raw = vaonNormalizedKnownDevices([d objectForKey:@"knownDevices"]);
		NSMutableArray *keptDevices = [NSMutableArray array];
		NSMutableSet *removedIds = [NSMutableSet set];
		for(NSDictionary *r in raw){
			BOOL match = [r[@"identifier"] isEqualToString:ident] || (nm.length && [r[@"name"] isEqualToString:nm]);
			if(match){ [removedIds addObject:r[@"identifier"]]; }
			else { [keptDevices addObject:r]; }
		}
		[d setObject:keptDevices forKey:@"knownDevices"];
		NSArray *rawPinned = vaonNormalizedPins([d objectForKey:@"pinnedDeviceIdentifiers"]);
		NSMutableArray *keptPins = [NSMutableArray array];
		for(NSString *pid in rawPinned){ if(![removedIds containsObject:pid]) [keptPins addObject:pid]; }
		[d setObject:keptPins forKey:@"pinnedDeviceIdentifiers"];
		[d synchronize];
		vaonPostChange();
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
	NSUserDefaults *_store;
	NSString *_currentSymbol;
}

	-(NSUserDefaults *)store {
		if(!_store) _store = [[NSUserDefaults alloc] initWithSuiteName:@"com.atar13.vaonprefs"];
		return _store;
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
		//resolved once here and kept in step in didSelectRow, rather than read back per row
		_currentSymbol = [self currentSymbol];
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
		NSString *current = _currentSymbol;
		BOOL selected = (sym.length == 0) ? (current.length == 0) : [current isEqualToString:sym];
		cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
		return cell;
	}

	-(NSString *)currentSymbol {
		NSArray *known = vaonNormalizedKnownDevices([[self store] objectForKey:@"knownDevices"]);
		for(NSDictionary *d in known){
			if(self.targetDeviceName.length && [d[@"name"] isEqualToString:self.targetDeviceName]){
				NSString *s = d[@"customGlyph"];
				if(s) return s;
			}
		}
		return @"";
	}

	-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		NSString *sym = _symbols[indexPath.row];
		NSUserDefaults *d = [self store];
		NSArray *raw = vaonNormalizedKnownDevices([d objectForKey:@"knownDevices"]);
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
		vaonPostChange();
		_currentSymbol = sym;
		[_tableView reloadData];
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
			double val = [cur isKindOfClass:[NSNumber class]] ? [cur doubleValue] : [specifier.properties[@"default"] doubleValue];
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
		vaonPostChange();
	}

@end