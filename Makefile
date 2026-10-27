APP_NAME = Subreply
EXECUTABLE_NAME = Macreply
BUNDLE_DIR = $(APP_NAME).app
CONTENTS_DIR = $(BUNDLE_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: build app run test clean

build:
	swift build -c release

app: build
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp ".build/release/$(EXECUTABLE_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	cp "AppIcon.icns" "$(RESOURCES_DIR)/AppIcon.icns"
	cp -R ".build/release/$(EXECUTABLE_NAME)_$(EXECUTABLE_NAME).bundle" "$(RESOURCES_DIR)/"
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'    <key>CFBundleDevelopmentRegion</key>' \
		'    <string>en</string>' \
		'    <key>CFBundleExecutable</key>' \
		'    <string>Subreply</string>' \
		'    <key>CFBundleIconFile</key>' \
		'    <string>AppIcon</string>' \
		'    <key>CFBundleIdentifier</key>' \
		'    <string>com.subreply.macreply</string>' \
		'    <key>CFBundleInfoDictionaryVersion</key>' \
		'    <string>6.0</string>' \
		'    <key>CFBundleName</key>' \
		'    <string>Subreply</string>' \
		'    <key>CFBundleDisplayName</key>' \
		'    <string>Subreply</string>' \
		'    <key>CFBundlePackageType</key>' \
		'    <string>APPL</string>' \
		'    <key>CFBundleShortVersionString</key>' \
		'    <string>2.0</string>' \
		'    <key>CFBundleVersion</key>' \
		'    <string>10</string>' \
		'    <key>LSMinimumSystemVersion</key>' \
		'    <string>14.0</string>' \
		'    <key>NSHighResolutionCapable</key>' \
		'    <true/>' \
		'    <key>NSPrincipalClass</key>' \
		'    <string>NSApplication</string>' \
		'</dict>' \
		'</plist>' > "$(CONTENTS_DIR)/Info.plist"
	touch "$(BUNDLE_DIR)"
	codesign --force --deep --sign - "$(BUNDLE_DIR)"

run: app
	open "$(BUNDLE_DIR)"

test:
	swift test

clean:
	swift package clean
	rm -rf "$(BUNDLE_DIR)"
