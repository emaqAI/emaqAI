cmake_minimum_required(VERSION 3.21)

# The toolchain file from PSn00bSDK must be passed via
# -DCMAKE_TOOLCHAIN_FILE, see build.sh.
project(
	tetris
	LANGUAGES C ASM
)

psn00bsdk_add_executable(tetris GPREL
	src/main.c
	src/game.c
	src/tetromino.c
	src/render.c
	src/input.c
	src/audio.c
	src/save.c
)

target_include_directories(tetris PRIVATE src)

# Link against the standard PSn00bSDK libraries.
psn00bsdk_add_cd_image(
	iso_image
	tetris
	iso/iso.xml
	DEPENDS tetris
)
