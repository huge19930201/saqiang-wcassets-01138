SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC := xcrun --sdk iphoneos clang
TARGET := build/WCAssetsUI.dylib
SOURCES := SaoqiangWCAssetsStore.m SaoqiangWCAssetsHooks.m SaoqiangWCAssetsUI.m SaoqiangWCAssetsInspector.m SaoqiangWCAssetsBubbles.m SaoqiangWCAssetsTheme.m SaoqiangWCAssetsThemePack.m SaoqiangWCAssetsReference.m SaoqiangWCAssetsPage.m SaoqiangWCAssetsNative.m SaoqiangWCAssetsPackNames.m SaoqiangWCAssetsZIP.c
MIN_IOS ?= 15.0
ARCH ?= arm64

.PHONY: all clean
all: $(TARGET)

$(TARGET): $(SOURCES) SaoqiangWCAssets.h SaoqiangWCAssetsInspector.h SaoqiangWCAssetsZIP.h SaoqiangWCAssetsTheme.h SaoqiangWCAssetsThemePack.h SaoqiangWCAssetsNative.h SaoqiangWCAssetsPackNames.h SaoqiangWCAssetsNames.h
	mkdir -p build
	$(CC) -arch $(ARCH) -isysroot "$(SDK)" -miphoneos-version-min=$(MIN_IOS) \
		-fobjc-arc -fblocks -O2 -Wall -Wextra -Wno-unused-parameter \
		-dynamiclib -install_name @rpath/WCAssetsUI.dylib \
		-framework Foundation -framework UIKit -framework ImageIO -framework CoreGraphics -framework QuartzCore -framework UniformTypeIdentifiers \
		$(SOURCES) -o "$@"

clean:
	rm -rf build
