import fitz
from pathlib import Path
from utils.logger import get_logger

logger = get_logger("generate_test_files")

def create_test_files():
    base_dir = Path(__file__).resolve().parent
    
    # 1. Create a clean PDF
    clean_path = base_dir / "test_clean.pdf"
    try:
        doc = fitz.open()
        page = doc.new_page()
        page.insert_text((50, 50), "Hello, this is a clean report document. It has zero macros, javascript, or external launch links.", fontsize=11)
        doc.save(str(clean_path))
        doc.close()
        logger.info(f"Created clean test PDF at {clean_path}")
    except Exception as e:
        logger.error(f"Failed to create clean test PDF: {e}")
        
    # 2. Create a suspicious PDF to test MEDIUM risk (some keywords but no payload)
    suspicious_path = base_dir / "test_suspicious.pdf"
    try:
        doc = fitz.open()
        page = doc.new_page()
        page.insert_text((50, 50), "This is a form with javascript.", fontsize=11)
        doc.save(str(suspicious_path))
        doc.close()
        
        with open(suspicious_path, "ab") as f:
            f.write(b"\n/JavaScript /JS /OpenAction\n")
            
        logger.info(f"Created suspicious test PDF at {suspicious_path}")
    except Exception as e:
        logger.error(f"Failed to create suspicious test PDF: {e}")

    # 3. Create a malicious PDF with embedded files, keywords, and high entropy
    dangerous_path = base_dir / "test_malicious.pdf"
    try:
        doc = fitz.open()
        page = doc.new_page()
        page.insert_text((50, 50), "Security policy alert! Please read the attached file payload.exe to verify.", fontsize=11)
        
        # Embed a file (this sets pdf_has_embedded_files=1, pdf_embedded_files_count=1)
        doc.embfile_add("payload.exe", b"MZ\x90\x00\x03\x00\x00\x00" + b"\x00"*64 + b"PowerShell cmdlet bypass execution payload", filename="payload.exe")
        doc.save(str(dangerous_path))
        doc.close()
        
        # Add high entropy random bytes and suspicious words to the raw file
        import os
        import random
        random_bytes = os.urandom(20000) # High entropy random data
        susp_text = b"\n" + b"/JavaScript /JS /Launch /OpenAction /RichMedia /SubmitForm\n" * 15
        
        with open(dangerous_path, "ab") as f:
            f.write(susp_text)
            f.write(random_bytes)
            
        logger.info(f"Created dangerous test PDF at {dangerous_path}")
    except Exception as e:
        logger.error(f"Failed to create dangerous test PDF: {e}")

if __name__ == "__main__":
    create_test_files()
