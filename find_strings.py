import os
import re

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Regex to find hardcoded strings inside Text() widgets
            matches = re.findall(r'Text\(\s*[\'"]([A-Za-z][^\'"]*)[\'"]', content)
            
            # Find labels, hints, titles, etc.
            matches += re.findall(r'(?:label|title|hintText|labelText|tooltip|heading|description)\s*:\s*[\'"]([A-Za-z][^\'"]*)[\'"]', content)
            
            if matches:
                print(f"{filepath}:")
                for match in matches:
                    print(f"  - {match}")
