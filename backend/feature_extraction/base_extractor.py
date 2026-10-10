from abc import ABC, abstractmethod
from typing import Dict, Any
from utils.file_utils import extract_general_info

class BaseExtractor(ABC):
    """
    Abstract base class for specific file type feature extractors.
    Automatically parses general file features (hashes, entropy, etc.).
    """
    def __init__(self):
        pass

    @abstractmethod
    def extract_specific(self, filepath: str) -> Dict[str, Any]:
        """
        To be implemented by specific file type extractor (PDF, Office, etc.).
        Returns dictionary of filetype-specific features.
        """
        pass

    def extract(self, filepath: str) -> Dict[str, Any]:
        """
        Combines general features and specific features into a single dict.
        """
        # Get general metadata features
        features = extract_general_info(filepath)
        
        # Get type-specific features
        specific_features = self.extract_specific(filepath)
        
        # Merge dictionaries
        features.update(specific_features)
        
        return features
