#!/bin/bash

set -o errexit

BASEDIR="$(dirname "$(realpath "$0")")/.."

PKGNAME="psytricks"

WINSW_RELEASE="2.12.0"
WINSW_FLAVOR="NET461"
WINSW_EXE="WinSW.$WINSW_FLAVOR.exe"
WINSW_URL="https://github.com/winsw/winsw/releases/download/v$WINSW_RELEASE/$WINSW_EXE"
WINSW_DIR="$BASEDIR/.winsw"

####
echo -n "Checking cached WinSW executable..."
test -d "$WINSW_DIR" || mkdir "$WINSW_DIR"
cd "$WINSW_DIR"
if ! [ -f "$WINSW_EXE" ]; then
    echo "Downloading $WINSW_URL"
    wget -q $WINSW_URL
fi
echo "[✔]"

####
echo -n "Locating build artifact..."
cd "$BASEDIR/dist"

TARGZ=$(find . -name '*.tar.gz')
if [ "$(echo "$TARGZ" | wc -l)" -ne "1" ]; then
    echo "Expecting exactly ONE .tar.gz file in the /dist/ folder!"
    exit 1
fi
TARGZ=${TARGZ:2}               # strip leading "./"
FULLNAME=${TARGZ%.tar.gz}      # strip the .tar.gz suffix
SUFFIX=${FULLNAME#"$PKGNAME"-} # strip the package name
echo "[✔]"

## something like this could be used to parse version components:
# PARSED=(${VERSION//./ })
# echo ${PARSED[0]}
# echo ${PARSED[1]}
# echo ${PARSED[2]}
# echo ${PARSED[3]}

####
echo -n "Checking target location..."
SERVICEDIR="${PKGNAME}-REST-${SUFFIX}_WinSW.$WINSW_FLAVOR-$WINSW_RELEASE"
if [ -d "$SERVICEDIR" ]; then
    echo "Target dir [$SERVICEDIR] already exists, stopping!"
    exit 2
fi
echo "[✔]"

####
echo -n -n "Extracting build artifact..."
tar xzf "$TARGZ"
echo "[✔]"

####
echo -n "Assembling service package..."
SOURCE="$FULLNAME/src/psytricks/__ps1__"
mv "$SOURCE" "$SERVICEDIR"
mv "$FULLNAME/README.md" "$SERVICEDIR"
rm "$SERVICEDIR/psytricks-wrapper.ps1"
rm -r "$SERVICEDIR/sampledata"

cp "$WINSW_DIR/$WINSW_EXE" "$SERVICEDIR/restricks-server.exe"
echo "[✔]"

####
echo -n "Creating service package artifact..."
zip -r -q "$SERVICEDIR.zip" "$SERVICEDIR"
echo "[✔]"

####
echo -n "Cleaning up..."
rm -r "$SERVICEDIR" "$FULLNAME"
echo "[✔]"

####
echo "============ dist/ ============"
tree -a "$BASEDIR/dist"
