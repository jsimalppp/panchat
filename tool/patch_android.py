#!/usr/bin/env python3
"""Run once after `flutter create --platforms=android --org com.panchat --project-name panchat .`

Patches the generated Android project for Panchat:
  * application id / namespace -> com.panchat.app (MainActivity moved to match)
  * minSdk 23 (flutter_secure_storage, record)
  * INTERNET + RECORD_AUDIO permissions
  * android:usesCleartextTraffic="false" (HTTPS only), allowBackup off, app label
Safe to run more than once.
"""
import os
import re
import shutil
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android")
ROOT = os.path.abspath(ROOT)
OLD, NEW = "com.panchat.panchat", "com.panchat.app"

if not os.path.isdir(ROOT):
    sys.exit("android/ not found. Run flutter create first.")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)


# 1. gradle: id, namespace, minSdk
for name in ("build.gradle.kts", "build.gradle"):
    p = os.path.join(ROOT, "app", name)
    if not os.path.exists(p):
        continue
    s = read(p).replace(OLD, NEW)
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", s)
    s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", s)
    write(p, s)
    print("patched", p)

# 2. MainActivity package + location
for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "app", "src", "main")):
    for fn in files:
        if fn.startswith("MainActivity.") and fn.endswith((".kt", ".java")):
            p = os.path.join(dirpath, fn)
            s = read(p)
            if OLD in s:
                s = s.replace(OLD, NEW)
                base = os.path.join(ROOT, "app", "src", "main", "kotlin" if fn.endswith(".kt") else "java")
                target_dir = os.path.join(base, *NEW.split("."))
                os.makedirs(target_dir, exist_ok=True)
                write(os.path.join(target_dir, fn), s)
                if os.path.abspath(p) != os.path.abspath(os.path.join(target_dir, fn)):
                    os.remove(p)
                print("moved", fn)

# 3. manifest
mp = os.path.join(ROOT, "app", "src", "main", "AndroidManifest.xml")
m = read(mp)
perms = [
    "android.permission.INTERNET",
    "android.permission.RECORD_AUDIO",
    "android.permission.MODIFY_AUDIO_SETTINGS",
]
add = "".join(
    '    <uses-permission android:name="%s"/>\n' % x for x in perms if x not in m
)
if add:
    m = m.replace("<application", add + "    <application", 1)
if "usesCleartextTraffic" not in m:
    m = m.replace("<application", '<application\n        android:usesCleartextTraffic="false"\n        android:allowBackup="false"', 1)
m = re.sub(r'android:label="[^"]*"', 'android:label="Panchat"', m, count=1)
write(mp, m)
print("patched manifest")
