#! /bin/bash

set -e;

while [ -z "$DMG_PATH" ]; do
  echo "ENTER DMG Path (REQUIRED e.g. ~/Desktop/AirtableInstaller.dmg)"
  read DMG_PATH
done
if [ ! ${DMG_PATH: -4} == ".dmg" ] || (( ${#DMG_PATH} < 4 )); then
  DMG_PATH+=".dmg"
  echo "DMG PATH: $DMG_PATH"
fi

echo "Enter Volume Name: (Airtable)"
read VOLUME_NAME
if [ -z "$VOLUME_NAME" ]; then
  VOLUME_NAME="Airtable"
fi

echo "Enter Volume Icon File Name or Path (icon.icns)"
read VOLUME_ICON_FILE
if [ -z "$VOLUME_ICON_FILE" ]; then
  VOLUME_ICON_FILE="icon.icns"
fi

echo "Enter Background Image File Name or Path (background.png)"
read BACKGROUND_FILE
if [ -z "$BACKGROUND_FILE" ]; then
  BACKGROUND_FILE="background.png"
fi
BACKGROUND_FILE_NAME="$(basename $BACKGROUND_FILE)"
BACKGROUND_CLAUSE="set background picture of opts to file \".background:$BACKGROUND_FILE_NAME\""
REPOSITION_HIDDEN_FILES_CLAUSE="set position of every item to {theBottomRightX + 100, 100}"

echo "Enter Icon Size (152)"
read ICON_SIZE
if [ -z $ICON_SIZE ]; then
  ICON_SIZE=152
fi
echo "Icon size set to $ICON_SIZE"

echo "Enter Text Size (12)"
read TEXT_SIZE
if [ -z $TEXT_SIZE ]; then
  TEXT_SIZE=12
fi
echo "Text size set to $TEXT_SIZE"

while [ ${#WIN_POS[@]} -lt 2 ] ; do
   echo "Enter Window Position x,y (300,250)"
   read WIN_POS_S
   if [ -z "$WIN_POS_S"]; then 
    WIN_POS_S="300,250"
   fi
   IFS=',' read -ra WIN_POS <<< "$WIN_POS_S"
 done 
WINX=${WIN_POS[0]}
WINY=${WIN_POS[1]}

while [[ ${#WIN_SIZE[@]} < 2 ]]; do
   echo "Enter Window Size width,height (610,310)"
   read WIN_SIZE_S
   if [ -z "$WIN_SIZE_S" ]; then
    WIN_SIZE_S="610,310"
   fi
   IFS=',' read -ra WIN_SIZE <<< "$WIN_SIZE_S"
 done 
WINW=${WIN_SIZE[0]}
WINH=${WIN_SIZE[1]}
echo "WinX:$WINX WinY:$WINY width:$WINW height:$WINH"


while [ -z "$APP_PATH" ]; do
  echo "Enter Application Path (REQUIRED e.g.: ../Airtable.app)"
  read APP_PATH
done
APP_NAME="$(basename $APP_PATH)"
echo "APP NAME: $APP_NAME"

while [[ ${#APP_POS[@]} < 2 ]]; do
   echo "Enter Application Icon Postion x,y (example: 120,150)"
   read APP_POS_S
   if [ -z "$APP_POS_S" ]; then
    APP_POS_S="120,150"
   fi
   IFS=',' read -ra APP_POS <<< "$APP_POS_S"
 done 
APPX=${APP_POS[0]}
APPY=${APP_POS[1]}
POSITION_CLAUSE="set position of item \"$APP_NAME\" to {$APPX, $APPY}"
echo "$POSITION_CLAUSE"

while [[ ${#DROP_POS[@]} < 2 ]]; do
   echo "Enter Applications Folder Icon Postion x,y (example: 490,150)"
   read DROP_POS_S
   if [ -z "$DROP_POS_S" ]; then
    DROP_POS_S="490,150"
   fi
   IFS=',' read -ra DROP_POS <<< "$DROP_POS_S"
 done 
DROPX=${DROP_POS[0]}
DROPY=${DROP_POS[1]}

APPLICATION_CLAUSE="set position of item \"Applications\" to {$DROPX, $DROPY}"
echo "$APPLICATION_CLAUSE"


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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

# fixes window postion, window size, icon size, text size, and positions
APPLESCRIPT=$(mktemp -t createdmg)
cat "$AUX_PATH/template.applescript" | sed -e "s/WINX/$WINX/g" -e "s/WINY/$WINY/g" -e "s/WINW/$WINW/g" -e "s/WINH/$WINH/g" -e "s/BACKGROUND_CLAUSE/$BACKGROUND_CLAUSE/g" -e "s/REPOSITION_HIDDEN_FILES_CLAUSE/$REPOSITION_HIDDEN_FILES_CLAUSE/g" -e "s/ICON_SIZE/$ICON_SIZE/g" -e "s/TEXT_SIZE/$TEXT_SIZE/g" | perl -pe  "s/POSITION_CLAUSE/$POSITION_CLAUSE/g" | perl -pe "s/APPLICATION_CLAUSE/$APPLICATION_CLAUSE/g">"$APPLESCRIPT"

echo "Running Applescript: /usr/bin/osascript \"${APPLESCRIPT}\" \"${VOLUME_NAME}\""
"/usr/bin/osascript" "${APPLESCRIPT}" "${VOLUME_NAME}" || true
echo "Done running the applescript..."
sleep 4

rm "$APPLESCRIPT"

# make sure it's not world writeable
echo "Fixing permissions..."
chmod -Rf go-w "${MOUNT_DIR}" &> /dev/null || true
echo "Done fixing permissions."

# opens folder on mount
echo "Blessing started"
bless --folder "${MOUNT_DIR}" --openfolder "${MOUNT_DIR}"
echo "Blessing finished"


echo "Disk image done"
exit 0