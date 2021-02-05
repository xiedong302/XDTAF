#!/bin/sh

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="XDTAF"
VERSION=$(date +%y.%m.%d)
CONFIGURATION="Release"

function buildFatFramework() {
	flags="OTHER_CFLAGS='-fembed-bitcode' -target $1 -configuration ${CONFIGURATION}"

	xcodebuild clean

	xcodebuild -sdk iphoneos ${flags} || exit 1

	xcodebuild -sdk iphonesimulator ${flags} || exit 1

	xcodebuild -create-xcframework \
	-framework "build/${CONFIGURATION}-iphoneos/$1.framework" \
	-framework "build/${CONFIGURATION}-iphonesimulator/$1.framework" \
	-output "${BASEDIR}/$1.xcframework"

	# 正式包不需要 构建 -framework "build/${CONFIGURATION}-iphonesimulator/$1.framework"
}

function build() {
	buildFatFramework "${PROJECT}"

	/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "./$PROJECT.framework/Info.plist"
	/usr/libexec/PlistBuddy -c "Set CFBundleVersion $VERSION" "./$PROJECT.framework/Info.plist"

	zip -r "${PROJECT}-${VERSION}.zip" "./${PROJECT}.xcframework"

	rm -r -f *.xcframework
}

rm -r -f build

rm -r -f *.zip

build
