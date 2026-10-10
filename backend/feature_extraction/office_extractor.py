import os
import zipfile
import re
from typing import Dict, Any
from xml.etree import ElementTree
from feature_extraction.base_extractor import BaseExtractor
from utils.logger import get_logger

# Import oletools.olevba carefully since it works on raw streams/files
try:
    from oletools.olevba import VBA_Parser
    OLE_AVAILABLE = True
except ImportError:
    OLE_AVAILABLE = False

logger = get_logger("office_extractor")

# Common executable extensions that shouldn't be inside an office document
EXE_EXTENSIONS = ['.exe', '.dll', '.scr', '.vbs', '.js', '.bat', '.cmd', '.ps1', '.msi', '.jar']

class OfficeExtractor(BaseExtractor):
    """
    Statically extracts features from Microsoft Office files (.docx, .xlsx, .pptx, .doc, .xls, .ppt).
    Parses OpenXML ZIP architecture for modern XML formats and uses oletools for OLE files.
    """

    def extract_specific(self, filepath: str) -> Dict[str, Any]:
        features = {
            "office_has_macros": 0,
            "office_macro_count": 0,
            "office_external_links_count": 0,
            "office_ole_objects_count": 0,
            "office_has_embedded_exe": 0,
            "office_has_auto_open": 0,
            "office_num_hidden_elements": 0,  # hidden sheets in Excel, hidden slides in PPT
            "office_num_relationships": 0,
            "office_has_metadata": 0,
            "office_compression_ratio": 1.0
        }

        # 1. VBA Macro Detection (using olevba if available)
        is_zip = zipfile.is_zipfile(filepath)
        is_ole = False
        try:
            import olefile
            is_ole = olefile.isOleFile(filepath)
        except Exception:
            pass

        if not is_zip and not is_ole:
            raise ValueError(f"File {filepath} is neither a valid ZIP nor OLE file.")

        if OLE_AVAILABLE:
            try:
                parser = VBA_Parser(filepath)
                if parser.detect_vba_macros():
                    features["office_has_macros"] = 1
                    # Extract macro code to parse counts & auto open functions
                    macros = parser.extract_macros()
                    features["office_macro_count"] = len(macros) if macros else 0
                    
                    # Search for auto-execution strings in macros
                    macro_code = ""
                    for _, _, _, code in macros:
                        if code:
                            macro_code += code + "\n"
                            
                    # Common AutoRun macro/function names
                    auto_run_names = [
                        "auto_open", "autoopen", "document_open", "documentopen", 
                        "workbook_open", "workbookopen", "autoexec", "autoexit", 
                        "document_close", "documentclose", "workbook_close", "workbookclose",
                        "auto_close", "autoclose"
                    ]
                    for name in auto_run_names:
                        if name in macro_code.lower():
                            features["office_has_auto_open"] = 1
                            break
                parser.close()
            except Exception as e:
                logger.debug(f"olevba parser error on {filepath} (file might match OpenXML structure but have no OLE structures): {e}")

        # 2. OpenXML ZIP Archive Structure Analysis
        if zipfile.is_zipfile(filepath):
            try:
                with zipfile.ZipFile(filepath, 'r') as zf:
                    # Calculate compression ratio: size of uncompressed data vs compressed size
                    total_uncompressed = 0
                    total_compressed = 0
                    num_relations = 0
                    ext_links = 0
                    ole_count = 0
                    hidden_elements = 0
                    has_exe = 0
                    has_metadata = 0
                    
                    file_list = zf.infolist()
                    for item in file_list:
                        total_uncompressed += item.file_size
                        total_compressed += item.compress_size
                        
                        # Count relationships (`.rels` files)
                        if item.filename.endswith(".rels"):
                            num_relations += 1
                            try:
                                rels_content = zf.read(item.filename)
                                # Count TargetMode="External" relationships (external hyperlinks, scripts, images)
                                ext_links += rels_content.count(b'TargetMode="External"')
                            except Exception:
                                pass
                                
                        # Count embedded OLE objects
                        if "embeddings/" in item.filename or "oleObject" in item.filename:
                            ole_count += 1
                            
                        # Search for embedded executable names in paths
                        item_lower = item.filename.lower()
                        for ext in EXE_EXTENSIONS:
                            if item_lower.endswith(ext):
                                has_exe = 1
                                break
                                
                        # Check metadata files
                        if "docProps/core.xml" in item.filename or "docProps/app.xml" in item.filename:
                            has_metadata = 1
                            
                        # Hidden elements:
                        # - Excel hidden sheets (in xl/workbook.xml)
                        if "xl/workbook.xml" == item.filename:
                            try:
                                wb_content = zf.read(item.filename)
                                root = ElementTree.fromstring(wb_content)
                                # Find all sheets elements
                                ns = {"ns": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
                                for sheet in root.findall(".//ns:sheet", ns):
                                    state = sheet.attrib.get("state")
                                    if state in ["hidden", "veryHidden"]:
                                        hidden_elements += 1
                            except Exception:
                                pass
                                
                        # - PPT hidden slides (in ppt/slides/slide*.xml)
                        if item.filename.startswith("ppt/slides/slide") and item.filename.endswith(".xml"):
                            try:
                                slide_content = zf.read(item.filename)
                                root = ElementTree.fromstring(slide_content)
                                # Hidden slides have show="0" attribute on the root p:sld element
                                show_val = root.attrib.get("show")
                                if show_val == "0":
                                    hidden_elements += 1
                            except Exception:
                                pass
                                
                        # - ActiveX Controls
                        if "activeX" in item_lower:
                            ole_count += 1
                            features["office_ole_objects_count"] = ole_count  # implicitly map activeX to OLE
                            
                        # - Document Comments (Word, Excel, PPT)
                        if "comments.xml" in item_lower or "comments" in item_lower:
                            if "office_comments_count" not in features:
                                features["office_comments_count"] = 0
                            features["office_comments_count"] += 1
                                
                    # Fill computed features
                    if total_compressed > 0:
                        features["office_compression_ratio"] = round(total_uncompressed / total_compressed, 4)
                        
                    features["office_num_relationships"] = num_relations
                    features["office_external_links_count"] = ext_links
                    features["office_ole_objects_count"] = ole_count
                    features["office_has_embedded_exe"] = has_exe
                    features["office_has_metadata"] = has_metadata
                    features["office_num_hidden_elements"] = hidden_elements
                    
            except Exception as e:
                logger.error(f"Error parsing ZIP structure of {filepath}: {e}")
                
        # 3. Legacy OLE File Parsing (e.g. .doc, .xls, .ppt)
        else:
            # If it's a legacy document (not ZIP), we check metadata / compression directly.
            # Usually these files are not compressed.
            features["office_compression_ratio"] = 1.0
            # ole_count can be inferred if it had OLE macros
            if features["office_has_macros"]:
                features["office_ole_objects_count"] = 1
                
        return features
