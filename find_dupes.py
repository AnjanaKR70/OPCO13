import re
from collections import Counter

with open('lib/services/localization_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# find all keys in _malayalamDictionary
start = text.find('_malayalamDictionary = {')
end = text.find('};', start)
dict_text = text[start:end]

keys = re.findall(r'"([^"]+)":', dict_text)
# Also check single quotes
keys += re.findall(r"'([^']+)':", dict_text)

counts = Counter(keys)
dupes = {k: v for k, v in counts.items() if v > 1}
print("DUPLICATES:", dupes)
