#!/bin/bash

exec > ~/tmp/check-notification.sh.log 2>&1
set -x
if test "$1"; then
    export ANDROID_SERIAL=$1
fi

# this script checks if wrench notification is working
notification_port=58888
if test "$WRENCH_INSTANCE"; then
    ((notification_port += WRENCH_INSTANCE)) || true
fi

timeout 2 telnet localhost $notification_port
ret=$?

if test "$ret" = 124; then
    exit 0
fi

bhj-notify Wrench "Can't connect to notification"
adb shell am start -a android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
