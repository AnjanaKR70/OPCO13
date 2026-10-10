from pathlib import Path
from utils.file_utils import get_mime_type
from feature_extraction.pdf_extractor import PDFExtractor
from feature_extraction.office_extractor import OfficeExtractor
from utils.logger import get_logger

logger = get_logger("extractor_factory")

class ExtractorFactory:
    @staticmethod
    def get_extractor(filepath: str):
        """
        Determines and returns the correct extractor instance for the given file.
        Throws ValueError if file type is unsupported.
        """
        mime = get_mime_type(filepath).lower()
        ext = Path(filepath).suffix.lower()
        
        # PDF Extractor mapping
        if mime == "application/pdf" or ext == ".pdf":
            return PDFExtractor()
            
        # Microsoft Office mapping
        office_mimes = [
            "application/msword",
            "application/vnd.openxmlformats-officedocument",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-word.document.macroenabled.12",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-excel.sheet.macroenabled.12",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "application/vnd.ms-powerpoint.presentation.macroenabled.12"
        ]
        
        office_exts = [".doc", ".docx", ".docm", ".xls", ".xlsx", ".xlsm", ".ppt", ".pptx", ".pptm"]
        
        if mime in office_mimes or ext in office_exts:
            return OfficeExtractor()
            
        raise ValueError(
            f"Unsupported file type. MIME: '{mime}', Ext: '{ext}'".format(mime=mime, ext=ext)
        )
