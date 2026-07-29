#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSViewController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>

@interface VaonRootListController : PSListController
@end

@interface VaonPinnedDevicesController : PSViewController <UITableViewDataSource, UITableViewDelegate>
@end

@interface VaonGlyphPickerController : PSViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *targetDeviceName;
@property (nonatomic, copy) NSString *targetDeviceIdentifier;
@end

@interface BatteryPreferenceController : PSListController
@end

@interface BatteryColorPreferenceController : PSListController
@end

@protocol PreferencesTableImageView
-(id)initWithSpecifier:(PSSpecifier *)specifier;
-(CGFloat)preferredHeightForWidth:(CGFloat)width;
@end 

@interface ImageCell : PSTableCell <PreferencesTableImageView> {
    UIImageView *imageView;
    UIImage *image;
}
@end

@interface VaonStepperCell : PSTableCell {
    UIStepper *_stepper;
    UILabel *_valueLabel;
}
@end