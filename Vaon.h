#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>

@interface SBSwitcherAppSuggestionContentView : UIView
@end

@interface BCBatteryDevice : NSObject
-(id)batteryWidgetGlyph;
-(long long)percentCharge;
-(BOOL)isBatterySaverModeActive;
-(BOOL)isCharging;
-(BOOL)isLowBattery;
-(BOOL)isInternal;
-(NSString *)identifier;
@property (nonatomic,readonly) long long productIdentifier;
-(NSString *)name;
-(BOOL)isConnected;
@end

@interface BCBatteryDeviceController : NSObject
+(id)_sharedPowerSourceController;
-(NSArray *)connectedDevices;
@end

//BluetoothManager sees every connected accessory, not just the ones that report a battery level
@interface BluetoothDevice : NSObject
-(NSString *)name;
-(NSString *)address;
-(int)batteryLevel;
-(unsigned)productId;
-(BOOL)connected;
-(BOOL)supportsBatteryLevel;
-(NSUInteger)connectedServicesCount;
@end

@interface BluetoothManager : NSObject
+(instancetype)sharedInstance;
-(NSArray *)connectedDevices;
-(NSArray *)pairedDevices;
@end

@interface VaonDeviceBatteryCell : UIStackView
-(instancetype)initWithFrame:(CGRect)arg1 device:(BCBatteryDevice *)device;
-(instancetype)initWithFrame:(CGRect)arg1 persistedRecord:(NSDictionary *)record;
-(instancetype)initWithFrame:(CGRect)arg1 bluetoothDevice:(BluetoothDevice *)device percentage:(long long)percentage;
@property (nonatomic, weak) BCBatteryDevice *device;
@property (nonatomic, strong) BluetoothDevice *bluetoothDevice;
@property (nonatomic) BOOL pinned;
@property (nonatomic, strong) NSString *deviceName;
@property (nonatomic) long long deviceProductIdentifier;
@property (nonatomic) NSString * deviceIdentifier;
@property (nonatomic) long long devicePercentage;
@property (nonatomic) CGFloat cellWidth;
@property (nonatomic, strong) UILabel *devicePercentageLabel;
@property (nonatomic, strong) UIBlurEffect *circleBackgroundBlurEffect;
@property (nonatomic, strong) UIVisualEffectView *circleBackgroundVisualEffectView;
@property (nonatomic, strong) NSMutableString *devicePercentageString;
@property (nonatomic, strong) UIBezierPath *circleOutlinePath;
@property (nonatomic, strong) CAShapeLayer *circleOutlineLayer;
@property (nonatomic, strong) UIImageView *deviceGlyphView;
@property (nonatomic, strong) CABasicAnimation *percentageAnimation;
//the cell owns both halves of the pulse so the two animations do not have to retain each other
@property (nonatomic, strong) CABasicAnimation *pulsateToBright;
@property (nonatomic, strong) CABasicAnimation *pulsateToNormal;
-(CGFloat)getCellWidth;
-(void)setCellWidth:(CGFloat)arg1;
-(void)addPercentageSymbolToLabel;
-(UIFont *)percentageFont;
-(CGFloat)percentageLabelHeight;
-(long long)getDevicePercentage;
-(void)updateDevicePercentage;
-(void)updateDevicePercentageLabel;
-(CGFloat)devicePercentageAsProgress;
-(BOOL)isDeviceConnected;
-(BOOL)hasBatteryReading;
-(BOOL)shouldPulsateOutline;
-(UIColor *)noBatteryConnectedColor;
-(BOOL)isDeviceInternal;
-(BOOL)isLowPowerModeOn;
-(BOOL)isBatteryLow;
-(void)updateOutlineColor;
-(void)pulsateOutline;
-(void)updatePercentageColor;
-(void)newAnimateOuterLayerToCurrentPercentage;
-(void)newAnimateOuterLayerToZero;
@end

@interface StrokeEndAnimationDelegate : NSObject <CAAnimationDelegate>
-(instancetype)initWithCell:(VaonDeviceBatteryCell *)cell;
@property (nonatomic, weak) VaonDeviceBatteryCell *cell;
-(void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag;
@end

@interface PulsateColorAnimationDelegate : NSObject <CAAnimationDelegate>
-(instancetype)initWithCell:(VaonDeviceBatteryCell *)cell nextAnimation:(CAAnimation *)nextAnimation;
@property (nonatomic, weak) VaonDeviceBatteryCell *cell;
@property (nonatomic, weak) CAAnimation *nextAnimation;
-(void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag;
@end

@interface SBApplication
-(id)bundleIdentifier;
@end
