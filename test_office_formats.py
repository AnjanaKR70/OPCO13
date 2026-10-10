import sys
import zipfile
import json
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path("backend").resolve()))

from api.scanner import scan_file

def create_zip(filename, contents):
    with zipfile.ZipFile(filename, "w") as zf:
        for name, data in contents.items():
            zf.writestr(name, data)

# 1. Benign DOCX, XLSX, PPTX
create_zip("benign.docx", {"[Content_Types].xml": "xml"})
create_zip("benign.xlsx", {"[Content_Types].xml": "xml"})
create_zip("benign.pptx", {"[Content_Types].xml": "xml"})

# 2. Benign hidden worksheet (returns Safe because score=25 < 30)
create_zip("hidden_sheet.xlsx", {
    "xl/workbook.xml": '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheets><sheet state="hidden"/></sheets></workbook>'
})

# 3. Suspicious external workbook relationship
create_zip("external_rel.xlsx", {
    "_rels/.rels": '<Relationship TargetMode="External"/><Relationship TargetMode="External"/>'
})

# 4. Macro-enabled document with a macro indicator (using .docm to route correctly)
# We can't safely test olevba execution in this mock without creating a real OLE file.
# But we can simulate by mocking the Extractor or testing something else.
# Wait, the user said "where safely testable". Let's test embedded executable instead for CRITICAL.
create_zip("embedded_exe.docx", {
    "word/embeddings/malware.exe": "MZ"
})

# 5. Malformed, encrypted, and unsupported
with open("unsupported.txt", "w") as f:
    f.write("hello world")

with open("malformed.docx", "w") as f:
    f.write("this is not a zip file")

print("--- SCAMUNDO OFFICE FORMAT TEST SUITE ---")
print("1. Benign DOCX:", json.dumps(scan_file("benign.docx"), indent=2))
print("2. Benign XLSX:", json.dumps(scan_file("benign.xlsx"), indent=2))
print("3. Benign PPTX:", json.dumps(scan_file("benign.pptx"), indent=2))
print("4. Hidden Worksheet (Should be Safe/25 points):", json.dumps(scan_file("hidden_sheet.xlsx"), indent=2))
print("5. External Relationships (Suspicious/50 points):", json.dumps(scan_file("external_rel.xlsx"), indent=2))
print("6. Embedded EXE (CRITICAL/85 points):", json.dumps(scan_file("embedded_exe.docx"), indent=2))
print("7. Unsupported TXT:", json.dumps(scan_file("unsupported.txt"), indent=2))
print("8. Malformed DOCX:", json.dumps(scan_file("malformed.docx"), indent=2))
