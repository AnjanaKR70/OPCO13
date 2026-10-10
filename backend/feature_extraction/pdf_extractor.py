import re
import fitz  # PyMuPDF
from typing import Dict, Any
from feature_extraction.base_extractor import BaseExtractor
from utils.logger import get_logger

logger = get_logger("pdf_extractor")

# PDF suspicious keywords list
SUSPICIOUS_PDF_KEYWORDS = [
    b"/JS", b"/JavaScript", b"/AA", b"/OpenAction", b"/Launch", 
    b"/ObjStm", b"/URI", b"/RichMedia", b"/SubmitForm", b"/AcroForm", b"/Encrypt"
]

class PDFExtractor(BaseExtractor):
    """
    Statically extracts features from PDF files.
    Does not execute javascript or open rendering windows.
    """
    
    def extract_specific(self, filepath: str) -> Dict[str, Any]:
        features = {
            "pdf_num_pages": 0,
            "pdf_has_javascript": 0,
            "pdf_js_count": 0,
            "pdf_has_embedded_files": 0,
            "pdf_embedded_files_count": 0,
            "pdf_has_openaction": 0,
            "pdf_has_launch_action": 0,
            "pdf_num_objects": 0,
            "pdf_num_streams": 0,
            "pdf_has_metadata": 0,
            "pdf_metadata_keys_count": 0,
            "pdf_is_encrypted": 0,
            "pdf_num_fonts": 0,
            "pdf_num_images": 0,
            "pdf_suspicious_keywords_count": 0
        }
        
        try:
            # Open the PDF using fitz (PyMuPDF) in static mode
            doc = fitz.open(filepath)
            
            features["pdf_num_pages"] = len(doc)
            features["pdf_is_encrypted"] = 1 if doc.is_encrypted else 0
            
            # Metadata features
            meta = doc.metadata
            if meta:
                # Filter out None values or keys
                valid_keys = [k for k, v in meta.items() if v]
                features["pdf_has_metadata"] = 1 if len(valid_keys) > 0 else 0
                features["pdf_metadata_keys_count"] = len(valid_keys)
                
            # Embedded Files count
            features["pdf_embedded_files_count"] = doc.embfile_count()
            features["pdf_has_embedded_files"] = 1 if doc.embfile_count() > 0 else 0
            
            # Count objects and streams
            features["pdf_num_objects"] = doc.xref_length() - 1 # Object counts
            
            # Check individual pages for fonts, images, and links/actions
            num_fonts = 0
            num_images = 0
            has_launch = 0
            has_openaction = 0
            has_js = 0
            js_count = 0
            num_streams = 0
            
            # Check PDF structural elements by inspecting raw xref entries securely
            # This is static search, we don't execute
            for xref in range(1, doc.xref_length()):
                try:
                    # Check if stream
                    if doc.is_stream(xref):
                        num_streams += 1
                        
                    # Check for JS or OpenAction inside target object definition
                    obj_defn = doc.xref_object(xref)
                    
                    if "/JS" in obj_defn or "/JavaScript" in obj_defn:
                        has_js = 1
                        # Increment JS counts based on occurrences
                        js_count += obj_defn.count("/JS") + obj_defn.count("/JavaScript")
                        
                    if "/OpenAction" in obj_defn:
                        has_openaction = 1
                        
                    if "/Launch" in obj_defn:
                        has_launch = 1
                except Exception:
                    continue
                    
            # Page-wise asset extraction
            for page_num in range(len(doc)):
                try:
                    page = doc[page_num]
                    # Fonts on page
                    fonts_list = page.get_fonts()
                    if fonts_list:
                        num_fonts += len(fonts_list)
                        
                    # Images on page
                    images_list = page.get_images()
                    if images_list:
                        num_images += len(images_list)
                except Exception:
                    continue
            
            features["pdf_num_fonts"] = num_fonts
            features["pdf_num_images"] = num_images
            features["pdf_num_streams"] = num_streams
            features["pdf_has_launch_action"] = has_launch
            features["pdf_has_openaction"] = has_openaction
            
            # Let's check for document level OpenAction
            # PyMuPDF lets us inspect catalogue dictionary
            try:
                # catalog object index
                catalog_xref = doc.pdf_catalog()
                if catalog_xref > 0:
                    catalog_obj = doc.xref_object(catalog_xref)
                    if "/OpenAction" in catalog_obj:
                        features["pdf_has_openaction"] = 1
                    if "/Names" in catalog_obj:
                        # names often holds JS arrays
                        has_js = 1
            except Exception:
                pass
                
            features["pdf_has_javascript"] = has_js
            features["pdf_js_count"] = js_count

        except Exception as e:
            logger.error(f"Error extracting PDF features from {filepath}: {e}")
            
        # Keyword-based raw scanning for PDF suspicious keywords
        try:
            keyword_count = 0
            with open(filepath, "rb") as f:
                # Read chunks to avoid large files memory bloating
                content = f.read(5 * 1024 * 1024)
                for keyword in SUSPICIOUS_PDF_KEYWORDS:
                    keyword_count += content.count(keyword)
            features["pdf_suspicious_keywords_count"] = keyword_count
        except Exception as e:
            logger.warning(f"Error scanning keyword bytes in PDF {filepath}: {e}")
            
        return features
