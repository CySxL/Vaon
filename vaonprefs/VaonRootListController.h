#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSViewController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>

//rows carrying gateKey leave the page while the switch or mode of that key is off
@interface VaonGatedListController : PSListController
-(NSMutableArray *)gatedSpecifiersFromPlistName:(NSString *)name;
@end

@interface VaonColorListController : VaonGatedListController <UIColorPickerViewControllerDelegate>
@end

@interface VaonRootListController : VaonGatedListController
@end

@interface VaonPinnedDevicesController : PSViewController <UITableViewDataSource, UITableViewDelegate>
@end

@interface VaonGlyphPickerController : PSViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *targetDeviceName;
@property (nonatomic, copy) NSString *targetDeviceIdentifier;
@end

@interface BatteryPreferenceController : VaonColorListController
@end

@interface BatteryColorPreferenceController : VaonColorListController
@end

@interface VaonStepperCell : PSTableCell {
    UIStepper *_stepper;
    UILabel *_valueLabel;
}
@end