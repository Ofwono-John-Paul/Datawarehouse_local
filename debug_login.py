#!/usr/bin/env python3
"""Debug login issue"""
import sys
sys.path.insert(0, '.')
from backend.main import SessionLocal, User
from sqlalchemy import or_
from werkzeug.security import check_password_hash

db = SessionLocal()

# Check what users exist
print("All users in database:")
for u in db.query(User).all():
    print(f"  - ID:{u.user_id}, Username: {u.username}, Email: {u.email}")

print("\nSearching for 'testuser'...")
user = db.query(User).filter(
    or_(User.username == "testuser", User.email == "testuser")
).first()

if user:
    print(f"Found user: {user.username}")
    print(f"Email: {user.email}")
    print(f"Password hash: {user.password[:50]}...")
    print(f"Checking password 'password123': {check_password_hash(user.password, 'password123')}")
else:
    print("User not found!")

db.close()
