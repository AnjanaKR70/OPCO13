import logging
import sys
from config import LOG_FORMAT, LOG_FILE

def get_logger(name: str) -> logging.Logger:
    """
    Returns a configured Logger instance.
    Logs to both console and a log file defined in config.py.
    """
    logger = logging.getLogger(name)
    if logger.hasHandlers():
        return logger

    logger.setLevel(logging.INFO)
    formatter = logging.Formatter(LOG_FORMAT)

    # Console Handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.INFO)
    logger.addHandler(console_handler)

    # File Handler
    try:
        file_handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
        file_handler.setFormatter(formatter)
        file_handler.setLevel(logging.INFO)
        logger.addHandler(file_handler)
    except Exception as e:
        print(f"Warning: Could not create file logger at {LOG_FILE}: {e}", file=sys.stderr)

    return logger
