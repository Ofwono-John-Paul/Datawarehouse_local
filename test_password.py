#!/usr/bin/env python3
"""Test password hashing"""
from werkzeug.security import generate_password_hash, check_password_hash

pwd = "password123"
hash1 = generate_password_hash(pwd)
hash2 = generate_password_hash(pwd)

print(f"Original password: {pwd}")
print(f"Hash 1: {hash1}")
print(f"Hash 2: {hash2}")
print()
print(f"Check hash1 against pwd: {check_password_hash(hash1, pwd)}")
print(f"Check hash2 against pwd: {check_password_hash(hash2, pwd)}")
print()

# Now check against the db
import sys
sys.path.insert(0, '.')
from backend.main import SessionLocal, User

db = SessionLocal()
user = db.query(User).filter_by(username="testuser").first()
if user:
    print(f"Found user: {user.username}")
    print(f"Password hash in DB: {user.password}")
    print(f"Check against 'password123': {check_password_hash(user.password, 'password123')}")
else:
    print("User not found!")
db.close()
