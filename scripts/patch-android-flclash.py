#!/usr/bin/env python3
"""Apply the minimal, reproducible Remnant VPN Android pilot overlay.

No upstream source is silently replaced. Every patch fails if its expected
pinned revision has changed. FlClash copyright and GPL-3.0 notices remain.
"""
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()


def replace_once(file: str, old: str, new: str) -> None:
    path = root / file
    content = path.read_text(encoding="utf-8")
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{file}: expected one match, got {count}: {old!r}")
    path.write_text(content.replace(old, new, 1), encoding="utf-8")


def remove_once(file: str, needle: str) -> None:
    replace_once(file, needle, "")


app = "android/app/build.gradle.kts"
remove_once(app, '    id("com.google.gms.google-services")\n')
remove_once(app, '    id("com.google.firebase.crashlytics")\n')
remove_once(app, "    implementation(platform(libs.firebase.bom))\n")
remove_once(app, "    implementation(libs.firebase.crashlytics.ndk)\n")
remove_once(app, "    implementation(libs.firebase.analytics)\n")
replace_once(
    app,
    '        applicationId = "com.follow.clash"',
    '        applicationId = "com.neyjealous.remnantvpn.android"',
)

common = "android/common/build.gradle.kts"
remove_once(common, "    implementation(platform(libs.firebase.bom))\n")
remove_once(common, "    implementation(libs.firebase.crashlytics.ndk)\n")
remove_once(common, "    implementation(libs.firebase.analytics)\n")

state = root / "android/common/src/main/java/com/follow/clash/common/GlobalState.kt"
content = state.read_text(encoding="utf-8")
for line in (
    "import com.google.firebase.FirebaseApp\n",
    "import com.google.firebase.crashlytics.FirebaseCrashlytics\n",
):
    if content.count(line) != 1:
        raise RuntimeError(f"GlobalState.kt: expected exactly one {line!r}")
    content = content.replace(line, "", 1)

start_marker = "    fun setCrashlytics(enable: Boolean) {"
end_marker = "    fun lastExitInfo(): Map<String, Any?>? {"
start = content.index(start_marker)
end = content.index(end_marker, start)
content = (
    content[:start]
    + "    // Telemetry is intentionally disabled in this private technical preview.\n"
    + "    fun setCrashlytics(enable: Boolean) = Unit\n\n"
    + "    fun didCrashOnPreviousExecution(): Boolean = false\n\n"
    + content[end:]
)
state.write_text(content, encoding="utf-8")

strings = "android/common/src/main/res/values/strings.xml"
replace_once(strings, '<string name="app_name">FlClash</string>',
             '<string name="app_name">Remnant VPN (Android)</string>')
replace_once(strings, '<string name="service_channel_name">FlClash Service</string>',
             '<string name="service_channel_name">Remnant VPN Service</string>')

print("Applied Remnant Android pilot overlay: own applicationId, launcher name, no Firebase.")
