TARGET := iphone:clang:latest:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = xl_tool

kif_FILES = \
	3rd/kif/CAAnimation+KIFAdditions.m            3rd/kif/KIFTestCase.m                         3rd/kif/KIFUITestActor-IdentifierTests.m      3rd/kif/NSString+KIFAdditions.m               3rd/kif/UITableView-KIFAdditions.m \
	3rd/kif/CALayer-KIFAdditions.m                3rd/kif/KIFTestStepValidation.m               3rd/kif/KIFUITestActor.m                      3rd/kif/UIAccessibilityElement-KIFAdditions.m 3rd/kif/UITouch-KIFAdditions.m     \
	3rd/kif/CGGeometry-KIFAdditions.m             3rd/kif/KIFTextInputTraitsOverrides.m         3rd/kif/KIFUIViewTestActor.m                  3rd/kif/UIApplication-KIFAdditions.m          3rd/kif/UIView-Debugging.m         \
	3rd/kif/IOHIDEvent+KIF.m                      3rd/kif/KIFTouchVisualizerView.m              3rd/kif/NSBundle-KIFAdditions.m               3rd/kif/UIAutomationHelper.m                  3rd/kif/UIView-KIFAdditions.m      \
	3rd/kif/KIFAccessibilityEnabler.m             3rd/kif/KIFTouchVisualizerViewCoordinator.m   3rd/kif/NSError-KIFAdditions.m                3rd/kif/UIDatePicker+KIFAdditions.m           3rd/kif/UIWindow-KIFAdditions.m    \
	3rd/kif/KIFEventVisualizer.m                  3rd/kif/KIFTypist.m                           3rd/kif/NSException-KIFAdditions.m            3rd/kif/UIEvent+KIFAdditions.m                3rd/kif/XCTestCase-KIFAdditions.m  \
	3rd/kif/KIFSystemTestActor.m                  3rd/kif/KIFUIObject.m                         3rd/kif/NSFileManager-KIFAdditions.m          3rd/kif/UIScreen+KIFAdditions.m                                                  \
	3rd/kif/KIFTestActor.m                        3rd/kif/KIFUITestActor-ConditionalTests.m     3rd/kif/NSPredicate+KIFAdditions.m            3rd/kif/UIScrollView-KIFAdditions.m

lua_FILES = \
	3rd/lua/lapi.c      3rd/lua/lcode.c     3rd/lua/ldblib.c  3rd/lua/ldump.c  3rd/lua/linit.c   3rd/lua/lmathlib.c  3rd/lua/lobject.c   3rd/lua/lparser.c  3rd/lua/lstrlib.c  3rd/lua/ltm.c       3rd/lua/lundump.c  \
	3rd/lua/lauxlib.c   3rd/lua/lcorolib.c  3rd/lua/ldebug.c  3rd/lua/lfunc.c  3rd/lua/liolib.c  3rd/lua/lmem.c      3rd/lua/lopcodes.c  3rd/lua/lstate.c   3rd/lua/ltable.c   3rd/lua/lutf8lib.c  3rd/lua/lzio.c     \
	3rd/lua/lbaselib.c  3rd/lua/lctype.c    3rd/lua/ldo.c     3rd/lua/lgc.c    3rd/lua/llex.c    3rd/lua/loadlib.c   3rd/lua/loslib.c    3rd/lua/lstring.c  3rd/lua/ltablib.c  3rd/lua/lvm.c
	# 3rd/lua/lua.c     3rd/lua/luac.c

minizip_FILES = \
	3rd/minizip/mz_strm.c          3rd/minizip/mz_strm_mem.c      3rd/minizip/mz_strm_wzaes.c \
	3rd/minizip/mz_strm_buf.c      3rd/minizip/mz_strm_os_posix.c 3rd/minizip/mz_strm_zlib.c \
	3rd/minizip/mz_compat.c        3rd/minizip/mz_os.c            3rd/minizip/mz_strm_pkcrypt.c \
	3rd/minizip/mz_crypt.c         3rd/minizip/mz_os_posix.c      3rd/minizip/mz_strm_libcomp.c  3rd/minizip/mz_zip.c \
	3rd/minizip/mz_crypt_apple.c   3rd/minizip/mz_strm_split.c    3rd/minizip/mz_zip_rw.c
minizip_DEFS = -DHAVE_PKCRYPT -DHAVE_WZAES -DHAVE_STDINT_H -DHAVE_ZLIB -DZLIB_COMPAT -DSTRICTZIP -DSTRICTUNZIP -DAPPLE

script_FILES = \
	scripts/main_lua_script._global.cpp \
	scripts/main_lua_script._json.cpp \
	scripts/main_lua.cpp \
	scripts/Lua_All.cpp scripts/Lua_Downloader.mm scripts/Lua_Crypto.mm scripts/Lua_Device.mm scripts/Lua_System.mm scripts/Lua_Task.cpp scripts/Lua_Logger.cpp

ios_FILES = \
	iOS/Limits.mm iOS/Events.mm iOS/FakeTouch.mm

x_FILES = \
	${minizip_FILES} \
	X_Fishhook.c \
	X_Lua.cpp ${lua_FILES} \
	X_OC.mm X_IO.mm X_Json.cpp X_Command.cpp \
	X_Logger.cpp X_Thread.cpp X_Chrono.cpp X_List.cpp X_String.cpp X_Byte.cpp X.mm

xl_tool_FILES = \
	main.xm \
	${kif_FILES} \
	${script_FILES} \
	${ios_FILES} \
	${x_FILES}

xl_tool_ExtraFrameworkPaths = -F ${THEOS}/sdks/iPhoneOS.Extended
xl_tool_CFLAGS  += -fobjc-arc -Wno-unused-function -Wno-deprecated -Wno-unused-but-set-variable ${xl_tool_ExtraFrameworkPaths} ${minizip_DEFS}
xl_tool_CCFLAGS += -std=c++17 -Wno-unused-function -Wno-deprecated -Wno-auto-var-id
xl_tool_LDFLAGS += ${xl_tool_ExtraFrameworkPaths}
xl_tool_FRAMEWORKS += IOKit XCTest
xl_tool_LIBRARIES = z
xl_tool_CODESIGN_FLAGS = -Sentitlements.plist
xl_tool_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
