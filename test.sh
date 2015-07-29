#! /bin/bash

# Create a read-only disk image of the contents of a folder

set -e;



function todo() {
  echo "TODO"
}

function usage() {
  version
  echo "Creates a fancy DMG file."
  echo "Usage:  $(basename $0) options... image.dmg source_folder"
  echo "All contents of source_folder will be copied into the disk image."
  echo "Options:"
  echo "  --volname name"
  echo "      set volume name (displayed in the Finder sidebar and window title)"
  echo "  --volicon icon.icns"
  echo "      set volume icon"
  echo "  --background pic.png"
  echo "      set folder background image (provide png, gif, jpg)"
  echo "  --window-pos x y"
  echo "      set position the folder window"
  echo "  --window-size width height"
  echo "      set size of the folder window"
  echo "  --text-size text_size"
  echo "      set window text size (10-16)"
  echo "  --icon-size icon_size"
  echo "      set window icons size (up to 128)"
  echo "  --icon file_name x y"
  echo "      set position of the file's icon"
  echo "  --hide-extension file_name"
  echo "      hide the extension of file"
  echo "  --custom-icon file_name custom_icon_or_sample_file x y"
  echo "      set position and custom icon"
  echo "  --app-drop-link x y"
  echo "      make a drop link to Applications, at location x,y"
  echo "  --eula eula_file"
  echo "      attach a license file to the dmg"
  echo "  --no-internet-enable"
  echo "      disable automatic mount&copy"
  echo "  --version         show tool version number"
  echo "  -h, --help        display this help"
  exit 0
}

WINX=10
WINY=60
WINW=500
WINH=350
ICON_SIZE=128
TEXT_SIZE=16

echo "ENTER DMG name (e.g. AirtableInstaller(.dmg))"
read DMG_PATH
if [ ! ${DMG_PATH: -4} == ".dmg" ] || (( ${#DMG_PATH} < 4 )); then
  DMG_PATH+=".dmg"
  echo "$DMG_PATH"
fi
echo "Enter Volume Name:"
read VOLUME_NAME

echo "Enter Volume Icon File Name or Path (icon.icns)"
read VOLUME_ICON_FILE

echo "Enter Background Image File Name or Path (background.png)"
read BACKGROUND_FILE
if  [ ! -z "$BACKGROUND_FILE" ]; then
  BACKGROUND_FILE_NAME="$(basename $BACKGROUND_FILE)"
  BACKGROUND_CLAUSE="set background picture of opts to file \".background:$BACKGROUND_FILE_NAME\""
  REPOSITION_HIDDEN_FILES_CLAUSE="set position of every item to {theBottomRightX + 100, 100}"
fi
echo "Enter Icon Size (recommended: 152)"
read ICON_SIZE
if [ -z $ICON_SIZE ]; then
  ICON_SIZE=152
fi
echo "Enter Text Size (recommended: 12)"
read TEXT_SIZE
if [ -z  $TEXT_SIZE ]; then
  TEXT_SIZE=12
fi
while [[ ${#WIN_POS[@]} < 2 ]]; do
   echo "Enter Window Position x,y (example: 300,250)"
   read WIN_POS_S
   IFS=',' read -ra WIN_POS <<< "$WIN_POS_S"
 done 
WINX=${WIN_POS[0]}
WINY=${WIN_POS[1]}

while [[ ${#WIN_SIZE[@]} < 2 ]]; do
   echo "Enter Window Size width,height (example: 650,300)"
   read WIN_SIZE_S
   IFS=',' read -ra WIN_SIZE <<< "$WIN_SIZE_S"
 done 
WINW=${WIN_SIZE[0]}
WINH=${WIN_SIZE[1]}

echo "Enter Application Path (e.g.: Airtable.app)"
read APP_PATH
APP_NAME="$(basename $APP_PATH)"
echo "$APP_NAME"
while [[ ${#APP_POS[@]} < 2 ]]; do
   echo "Enter Application Icon Postion x,y (example: 120,150)"
   read APP_POS_S
   IFS=',' read -ra APP_POS <<< "$APP_POS_S"
 done 
APPX=${APP_POS[0]}
APPY=${APP_POS[1]}
POSITION_CLAUSE="set position of item \"$APP_NAME\" to {$APPX, $APPY}"

while [[ ${#DROP_POS[@]} < 2 ]]; do
   echo "Enter Applications Folder Icon Postion x,y (example: 600,150)"
   read DROP_POS_S
   IFS=',' read -ra DROP_POS <<< "$DROP_POS_S"
 done 
DROPX=${DROP_POS[0]}
DROPY=${DROP_POS[1]}

APPLICATION_CLAUSE="set position of item \"Applications\" to {$DROPX, $DROPY}"


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# DMG_PATH="$1"
DMG_DIRNAME="$(dirname "$DMG_PATH")"
DMG_DIR="$(cd "$DMG_DIRNAME" > /dev/null; pwd)"
DMG_NAME="$(basename "$DMG_PATH")"
DMG_TEMP_NAME="$DMG_DIR/${DMG_NAME}"
# SRC_FOLDER="$(cd "$APP_PATH" > /dev/null; pwd)"
SRC_FOLDER="$APP_PATH"
test -z "$VOLUME_NAME" && VOLUME_NAME="$(basename "$DMG_PATH" .dmg)"

AUX_PATH="$SCRIPT_DIR/support"

test -d "$AUX_PATH" || {
  echo "Cannot find support directory: $AUX_PATH"
  exit 1
}

if [ -f "$SRC_FOLDER/.DS_Store" ]; then
    echo "Deleting any .DS_Store in source folder"
    rm "$SRC_FOLDER/.DS_Store"
fi

# Create the image
echo "Creating disk image..."
test -f "${DMG_TEMP_NAME}" && rm -f "${DMG_TEMP_NAME}"
ACTUAL_SIZE=`du -sm "$SRC_FOLDER" | sed -e 's/  .*//g'`
echo "$ACTUAL_SIZE"
read -r ACTUAL_SIZE _ <<< "$ACTUAL_SIZE"

DISK_IMAGE_SIZE=`expr $ACTUAL_SIZE + 5`
hdiutil create -srcfolder "$SRC_FOLDER" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DISK_IMAGE_SIZE}m "${DMG_TEMP_NAME}"

# mount it
echo "Mounting disk image..."
MOUNT_DIR="/Volumes/${VOLUME_NAME}"

# try unmount dmg if it was mounted previously (e.g. developer mounted dmg, installed app and forgot to unmount it)
echo "Unmounting disk image..."
DEV_NAME=$(hdiutil info | egrep '^/dev/' | sed 1q | awk '{print $1}')
test -d "${MOUNT_DIR}" && hdiutil detach "${DEV_NAME}"

echo "Mount directory: $MOUNT_DIR"
echo "${DMG_TEMP_NAME}"
DEV_NAME=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP_NAME}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
echo "Device name:     $DEV_NAME"

if ! test -z "$BACKGROUND_FILE"; then
  echo "Copying background file..."
  test -d "$MOUNT_DIR/.background" || mkdir "$MOUNT_DIR/.background"
  cp "$BACKGROUND_FILE" "$MOUNT_DIR/.background/$BACKGROUND_FILE_NAME"
fi


echo "making link to Applications dir"
echo $MOUNT_DIR
ln -s /Applications "$MOUNT_DIR/Applications"


if ! test -z "$VOLUME_ICON_FILE"; then
  echo "Copying volume icon file '$VOLUME_ICON_FILE'..."
  cp "$VOLUME_ICON_FILE" "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_DIR"
fi


APPLESCRIPT=$(mktemp -t createdmg)
cat "$AUX_PATH/template.applescript" | sed -e "s/WINX/$WINX/g" -e "s/WINY/$WINY/g" -e "s/WINW/$WINW/g" -e "s/WINH/$WINH/g" -e "s/BACKGROUND_CLAUSE/$BACKGROUND_CLAUSE/g" -e "s/REPOSITION_HIDDEN_FILES_CLAUSE/$REPOSITION_HIDDEN_FILES_CLAUSE/g" -e "s/ICON_SIZE/$ICON_SIZE/g" -e "s/TEXT_SIZE/$TEXT_SIZE/g" | perl -pe  "s/POSITION_CLAUSE/$POSITION_CLAUSE/g" | perl -pe "s/APPLICATION_CLAUSE/$APPLICATION_CLAUSE/g">"$APPLESCRIPT"

echo "Running Applescript: /usr/bin/osascript \"${APPLESCRIPT}\" \"${VOLUME_NAME}\""
"/usr/bin/osascript" "${APPLESCRIPT}" "${VOLUME_NAME}" || true
echo "Done running the applescript..."
sleep 4

rm "$APPLESCRIPT"


echo "Disk image done"
exit 0