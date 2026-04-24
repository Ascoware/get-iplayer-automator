#!/bin/sh
PROJECT_DIR=$(pwd)/.
PBXPROJ="Get iPlayer Automator.xcodeproj/project.pbxproj"
buildString=$(date +'%Y%m%d%H%M')
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = $buildString/" "${PROJECT_DIR}/${PBXPROJ}"
