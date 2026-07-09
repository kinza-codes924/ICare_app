import os
import shutil
import tempfile

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

def clean_directory(path, name):
    if not os.path.exists(path):
        return 0
    
    size_before = get_size(path)
    print(f"\n{name}: {size_before / (1024**3):.2f} GB")
    
    try:
        for item in os.listdir(path):
            item_path = os.path.join(path, item)
            try:
                if os.path.isfile(item_path):
                    os.unlink(item_path)
                elif os.path.isdir(item_path):
                    shutil.rmtree(item_path)
            except Exception as e:
                print(f"  Skip: {item}")
    except Exception as e:
        print(f"  Error: {e}")
    
    size_after = get_size(path)
    freed = (size_before - size_after) / (1024**3)
    print(f"  Freed: {freed:.2f} GB")
    return freed

print("=== Cache Cleaner ===\n")

total_freed = 0

# Windows Temp
total_freed += clean_directory(tempfile.gettempdir(), "Windows Temp")

# User Temp
user_temp = os.path.join(os.environ.get('USERPROFILE', 'C:\\'), 'AppData', 'Local', 'Temp')
total_freed += clean_directory(user_temp, "User Temp")

# Windows Prefetch
total_freed += clean_directory('C:\\Windows\\Prefetch', "Prefetch")

# Windows Temp
total_freed += clean_directory('C:\\Windows\\Temp', "Windows System Temp")

# Browser Caches
user_profile = os.environ.get('USERPROFILE', 'C:\\')

# Chrome
chrome_cache = os.path.join(user_profile, 'AppData', 'Local', 'Google', 'Chrome', 'User Data', 'Default', 'Cache')
total_freed += clean_directory(chrome_cache, "Chrome Cache")

# Edge
edge_cache = os.path.join(user_profile, 'AppData', 'Local', 'Microsoft', 'Edge', 'User Data', 'Default', 'Cache')
total_freed += clean_directory(edge_cache, "Edge Cache")

# Firefox
firefox_cache = os.path.join(user_profile, 'AppData', 'Local', 'Mozilla', 'Firefox', 'Profiles')
total_freed += clean_directory(firefox_cache, "Firefox Cache")

# Flutter Cache
flutter_cache = os.path.join(user_profile, 'AppData', 'Local', 'Pub', 'Cache')
total_freed += clean_directory(flutter_cache, "Flutter Pub Cache")

# Gradle Cache
gradle_cache = os.path.join(user_profile, '.gradle', 'caches')
total_freed += clean_directory(gradle_cache, "Gradle Cache")

# Android Build Cache
android_cache = os.path.join(user_profile, '.android', 'build-cache')
total_freed += clean_directory(android_cache, "Android Build Cache")

print(f"\n{'='*40}")
print(f"Total Freed: {total_freed:.2f} GB")
print(f"{'='*40}")
