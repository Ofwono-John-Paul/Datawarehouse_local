import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

class Config:
    LOCAL_DB_PATH = Path(__file__).resolve().parent / "local.db"
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL", f"sqlite:///{LOCAL_DB_PATH.as_posix()}")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}