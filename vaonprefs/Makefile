include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = VaonPrefs

VaonPrefs_FILES = VaonRootListController.m
VaonPrefs_FRAMEWORKS = UIKit
VaonPrefs_PRIVATE_FRAMEWORKS = Preferences
VaonPrefs_INSTALL_PATH = /Library/PreferenceBundles
VaonPrefs_CFLAGS = -fobjc-arc
VaonPrefs_LIBRARIES = colorpicker

# Version shown in the settings header, taken from control
VAON_VERSION := $(shell sed -n 's/^Version: //p' $(THEOS_PROJECT_DIR)/control)
ifeq ($(VAON_VERSION),)
$(error no Version line in $(THEOS_PROJECT_DIR)/control)
endif
VaonPrefs_CFLAGS += -DPACKAGE_VERSION='"$(VAON_VERSION)"'

include $(THEOS_MAKE_PATH)/bundle.mk
