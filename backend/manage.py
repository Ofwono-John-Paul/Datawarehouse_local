import os
from pathlib import Path

from flask import Flask
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy

import main


LOCAL_DB_PATH = Path(__file__).resolve().parent / "local.db"
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{LOCAL_DB_PATH.as_posix()}")


app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = DATABASE_URL
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {"pool_pre_ping": True}
print(f"Flask DATABASE_URL loaded: {'yes' if DATABASE_URL else 'no'}")

# Reuse SQLAlchemy metadata defined in FastAPI models.
db = SQLAlchemy(app, metadata=main.Base.metadata)
migrate = Migrate(app, db, compare_type=True)
