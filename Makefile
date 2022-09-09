TARGET := iphone:clang:latest:13.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = xl_tool

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
	iOS/Limits.mm

x_FILES = \
	${minizip_FILES} \
	X_Fishhook.c \
	X_Lua.cpp ${lua_FILES} \
	X_OC.mm X_IO.mm X_Json.cpp X_Command.cpp \
	X_Logger.cpp X_Thread.cpp X_Chrono.cpp X_List.cpp X_String.cpp X_Byte.cpp X.mm

xl_tool_FILES = \
	main.xm \
	${script_FILES} \
	${ios_FILES} \
	${x_FILES}

xl_tool_CFLAGS = -fobjc-arc -Wno-unused-function -Wno-unused-but-set-variable ${minizip_DEFS}
xl_tool_CCFLAGS = -std=c++17 -Wno-unused-function -Wno-deprecated -Wno-auto-var-id
xl_tool_LIBRARIES = z
xl_tool_CODESIGN_FLAGS = -Sentitlements.plist
xl_tool_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
