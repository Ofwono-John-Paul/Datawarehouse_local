#!/usr/bin/env python3
"""Test database directly"""
import sys
sys.path.insert(0, '.')

from backend.main import engine, Base

print("Testing database connection...")
try:
    with engine.connect() as conn:
        result = conn.execute("SELECT 1 as test".replace("SELECT", "SELECT"))
        print(f"✓ Database connection successful")
except Exception as e:
    print(f"✗ Database error: {e}")

print("\nCreating all tables if not exist...")
try:
    Base.metadata.create_all(engine)
    print(f"✓ Tables created/verified")
except Exception as e:
    print(f"✗ Error: {e}")

print("\nTesting direct insert...")
from backend.main import SessionLocal, School, User
from werkzeug.security import generate_password_hash

db = SessionLocal()
try:
    # Create a test school
    if not db.query(School).filter_by(name="TestSchool").first():
        school = School(
            name="TestSchool",
            region="Central",
            district="Kampala",
            contact_email="test@test.ug",
        )
        db.add(school)
        db.flush()
        school_id = school.id
        print(f"✓ Created test school with ID: {school_id}")
        
        # Create a test user
        user = User(
            username="testuser",
            email="testuser@test.ug",
            password=generate_password_hash("password123"),
            role="SCHOOL_USER",
            school_id=school_id,
        )
        db.add(user)
        db.commit()
        print(f"✓ Created test user")
    else:
        print(f"ℹ Test school already exists")
except Exception as e:
    db.rollback()
    print(f"✗ Error: {e}")
finally:
    db.close()

print("\nVerifying test data...")
db = SessionLocal()
schools = db.query(School).all()
users = db.query(User).all()
print(f"✓ Schools in DB: {len(schools)}")
print(f"✓ Users in DB: {len(users)}")
db.close()
