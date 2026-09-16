TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := Torium

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ToriumHelper

ToriumHelper_FILES = ToriumHelper.x
ToriumHelper_CFLAGS = -fobjc-arc
ToriumHelper_FRAMEWORKS = UIKit Foundation CFNetwork

include $(THEOS_MAKE_PATH)/tweak.mk
