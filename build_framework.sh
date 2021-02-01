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

	cp -r "build/${CONFIGURATION}-iphoneos/$1.framework" "${BASEDIR}"

	lipo -create "build/${CONFIGURATION}-iphonesimulator/$1.framework/$1" "build/${CONFIGURATION}-iphoneos/$1.framework/$1" -output "${BASEDIR}/$1.framework/$1"
}

function build() {
	buildFatFramework "${PROJECT}"

	/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "./$PROJECT.framework/Info.plist"
	/usr/libexec/PlistBuddy -c "Set CFBundleVersion $VERSION" "./$PROJECT.framework/Info.plist"

	zip -r "${PROJECT}-${VERSION}.zip" "./${PROJECT}.framework"

	rm -r -f *.framework
}


rm -r -f build

rm -r -f *.zip

build
