import math
import hashlib
import mimetypes
import os
import re
from datetime import datetime, timezone
import collections
from pathlib import Path
from utils.logger import get_logger

logger = get_logger("file_utils")

# Regex patterns
URL_REGEX = re.compile(r'https?://[^\s/$.?#].[^\s]*', re.IGNORECASE)
EMAIL_REGEX = re.compile(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')

# Suspicious payload regexes (e.g. shellcode, powershell, cmd, base64 indicators, scripting signatures)
SUSPICIOUS_REGEXES = [
    re.compile(r'powershell(?:\.exe)?', re.IGNORECASE),
    re.compile(r'cmd(?:\.exe)?\s+/c', re.IGNORECASE),
    re.compile(r'bypassabout|wscript\.shell|shell\.application|createobject', re.IGNORECASE),
    re.compile(r'autoexec|auto_open|document_open|workbook_open|document_close', re.IGNORECASE),
    re.compile(r'eval\s*\(|unescape\s*\(|exec\.Command|shell_exec', re.IGNORECASE),
    re.compile(r'((?:[A-Za-z0-9+/]{4}){10,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?)') # long base64 string
]

def get_file_hashes(filepath: str) -> dict:
    """Returns SHA256 and MD5 hashes of a file."""
    sha256_hash = hashlib.sha256()
    md5_hash = hashlib.md5()
    
    try:
        with open(filepath, "rb") as f:
            for byte_block in iter(lambda: f.read(65536), b""):
                sha256_hash.update(byte_block)
                md5_hash.update(byte_block)
        return {
            "sha256": sha256_hash.hexdigest(),
            "md5": md5_hash.hexdigest()
        }
    except Exception as e:
        logger.error(f"Error calculating hashes for {filepath}: {e}")
        return {"sha256": "", "md5": ""}

def get_mime_type(filepath: str) -> str:
    """Guesses the MIME type of a file based on its magic signature, then extension."""
    try:
        with open(filepath, "rb") as f:
            header = f.read(8)
            if header.startswith(b'%PDF'):
                return "application/pdf"
            if header.startswith(b'PK\x03\x04'):
                # Validate it's actually OpenXML, not just a random ZIP
                import zipfile
                try:
                    with zipfile.ZipFile(filepath, 'r') as zf:
                        if '[Content_Types].xml' in zf.namelist():
                            return "application/vnd.openxmlformats-officedocument" # Generic OpenXML
                except Exception:
                    pass
                return "application/zip" # Fallback for arbitrary ZIPs
            if header.startswith(b'\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1'):
                return "application/msword" # Generic Legacy OLE
    except Exception as e:
        logger.debug(f"Could not read magic bytes for {filepath}: {e}")

    mime, _ = mimetypes.guess_type(filepath)
    if mime:
        return mime
    
    # Fallback based on extension
    ext = Path(filepath).suffix.lower()
    mapping = {
        ".pdf": "application/pdf",
        ".doc": "application/msword",
        ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ".xls": "application/vnd.ms-excel",
        ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ".ppt": "application/vnd.ms-powerpoint",
        ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    }
    return mapping.get(ext, "application/octet-stream")

def calculate_entropy(filepath: str) -> float:
    """Calculates the byte entropy of a file (range 0 to 8)."""
    try:
        total_bytes = 0
        counts = collections.Counter()
        
        with open(filepath, "rb") as f:
            for byte_block in iter(lambda: f.read(65536), b""):
                counts.update(byte_block)
                total_bytes += len(byte_block)
        
        if total_bytes == 0:
            return 0.0
            
        entropy = 0.0
        for count in counts.values():
            p_x = count / total_bytes
            entropy += - p_x * math.log2(p_x)
            
        return round(float(entropy), 4)
    except Exception as e:
        logger.error(f"Error calculating entropy for {filepath}: {e}")
        return 0.0

def extract_general_info(filepath: str) -> dict:
    """
    Extracts general metadata features:
    - sha256
    - md5
    - file_size (bytes)
    - mime_type
    - creation_time
    - modification_time
    - age_days (relative to now)
    - time_delta_days (mod_time - create_time)
    - url_count
    - email_count
    - suspicious_strings_count
    - entropy
    """
    path = Path(filepath)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {filepath}")
        
    stat = path.stat()
    file_size = stat.st_size
    
    # Times (using UTC timestamps)
    try:
        # On Windows st_ctime is creation time, on Unix st_ctime is metadata change time
        create_time = stat.st_ctime
        mod_time = stat.st_mtime
    except Exception:
        create_time = os.path.getctime(filepath)
        mod_time = os.path.getmtime(filepath)
        
    now = datetime.now(timezone.utc).timestamp()
    age_days = max(0.0, (now - create_time) / 86400.0)
    time_delta_days = max(0.0, (mod_time - create_time) / 86400.0)
    
    hashes = get_file_hashes(filepath)
    mime_type = get_mime_type(filepath)
    entropy = calculate_entropy(filepath)
    
    # Content-based scanning (Safe for text, handle strings of raw bytes)
    # We do a simple ASCII decode with ignore or scan binary payload for ASCII printable sequences
    url_count = 0
    email_count = 0
    suspicious_strings_count = 0
    
    try:
        # Read as binary, convert to printable ASCII to run regex on
        with open(filepath, "rb") as f:
            content = f.read(5 * 1024 * 1024) # Scan first 5MB to prevent memory exhaustion on huge files
            content_str = content.decode("utf-8", errors="ignore")
            
            url_count = len(URL_REGEX.findall(content_str))
            email_count = len(EMAIL_REGEX.findall(content_str))
            
            for rx in SUSPICIOUS_REGEXES:
                suspicious_strings_count += len(rx.findall(content_str))
    except Exception as e:
        logger.warning(f"Error scanning strings in {filepath}: {e}")
        
    return {
        "sha256": hashes["sha256"],
        "md5": hashes["md5"],
        "file_size": file_size,
        "mime_type": mime_type,
        "age_days": round(age_days, 2),
        "time_delta_days": round(time_delta_days, 2),
        "url_count": url_count,
        "email_count": email_count,
        "suspicious_strings_count": suspicious_strings_count,
        "entropy": entropy
    }
