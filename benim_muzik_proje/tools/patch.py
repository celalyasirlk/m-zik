import re
m='android/app/src/main/AndroidManifest.xml'
s=open(m,encoding='utf8').read()
perms='''<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    '''
s=s.replace('<application',perms+'<application',1)
s=re.sub(r'android:label="[^"]*"','android:label="Müzik"',s,1)
extra='''<service android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback" android:exported="true">
            <intent-filter><action android:name="android.media.browse.MediaBrowserService"/></intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true">
            <intent-filter><action android:name="android.intent.action.MEDIA_BUTTON"/></intent-filter>
        </receiver>
    </application>'''
s=s.replace('</application>',extra,1)
open(m,'w',encoding='utf8').write(s)
import glob
k=glob.glob('android/app/src/main/kotlin/**/MainActivity.kt',recursive=True)[0]
open(k,'w').write('package com.kisisel.benim_muzik\n\nimport com.ryanheise.audioservice.AudioServiceActivity\n\nclass MainActivity : AudioServiceActivity()\n')
