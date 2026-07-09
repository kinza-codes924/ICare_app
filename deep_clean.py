import os
import shutil
import subprocess

def get_size(path):
    total = 0
    try:
        if os.path.isfile(path):
            total = os.path.getsize(path)
        elif os.path.isdir(path):
            for entry in os.scandir(path):
                try:
                    total += get_size(entry.path)
                except:
                    pass
    except:
        pass
    return total

def delete_folder(path, name):
    if not os.path.exists(path):
        return 0
    
    size = get_size(path)
    print(f"\n{name}: {size / (1024**3):.2f} GB")
    
    try:
        shutil.rmtree(path)
        print(f"  ✓ Deleted: {size / (1024**3):.2f} GB")
        return size / (1024**3)
    except Exception as e:
        print(f"  ✗ Failed: {e}")
        return 0

print("=== Advanced Cache Cleaner ===\n")

total_freed = 0
user_profile = os.environ.get('USERPROFILE', 'C:\\')

# Flutter project build folders
print("\n--- Flutter Build Folders ---")
project_root = r"d:\ICare_app-wajahat\ICare_app-wajahat"
if os.path.exists(project_root):
    total_freed += delete_folder(os.path.join(project_root, "build"), "Flutter Build")
    total_freed += delete_folder(os.path.join(project_root, ".dart_tool"), "Dart Tool")
    
    android_build = os.path.join(project_root, "android", ".gradle")
    total_freed += delete_folder(android_build, "Android Gradle")

# Pub cache
print("\n--- Pub/Flutter Cache ---")
pub_cache = os.path.join(user_profile, "AppData", "Local", "Pub", "Cache")
total_freed += delete_folder(pub_cache, "Pub Cache")

flutter_cache = os.path.join(user_profile, "AppData", "Local", "flutter")
total_freed += delete_folder(flutter_cache, "Flutter Local")

# Gradle
print("\n--- Gradle Cache ---")
gradle_cache = os.path.join(user_profile, ".gradle", "caches")
total_freed += delete_folder(gradle_cache, "Gradle Caches")

gradle_wrapper = os.path.join(user_profile, ".gradle", "wrapper")
total_freed += delete_folder(gradle_wrapper, "Gradle Wrapper")

# Android
print("\n--- Android Cache ---")
android_cache = os.path.join(user_profile, ".android", "build-cache")
total_freed += delete_folder(android_cache, "Android Build Cache")

android_avd = os.path.join(user_profile, ".android", "avd")
if os.path.exists(android_avd):
    size = get_size(android_avd)
    print(f"\nAndroid AVD: {size / (1024**3):.2f} GB (Skipped - manual delete if needed)")

# VS Code
print("\n--- VS Code Cache ---")
vscode_cache = os.path.join(user_profile, "AppData", "Roaming", "Code", "Cache")
total_freed += delete_folder(vscode_cache, "VS Code Cache")

vscode_cache2 = os.path.join(user_profile, "AppData", "Roaming", "Code", "CachedData")
total_freed += delete_folder(vscode_cache2, "VS Code Cached Data")

# npm cache
print("\n--- NPM Cache ---")
npm_cache = os.path.join(user_profile, "AppData", "Roaming", "npm-cache")
total_freed += delete_folder(npm_cache, "NPM Cache")

# Windows Update
print("\n--- Windows Update Cache ---")
win_update = r"C:\Windows\SoftwareDistribution\Download"
total_freed += delete_folder(win_update, "Windows Update Downloads")

print(f"\n{'='*50}")
print(f"Total Freed: {total_freed:.2f} GB")
print(f"{'='*50}")

# Run Windows Disk Cleanup
print("\n--- Running Windows Disk Cleanup ---")
try:
    subprocess.run(["cleanmgr", "/sagerun:1"], check=False)
    print("Disk Cleanup launched!")
except:
    print("Could not launch Disk Cleanup")
