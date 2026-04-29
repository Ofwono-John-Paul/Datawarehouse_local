#!/usr/bin/env python3
"""Check database contents"""
import sys
sys.path.insert(0, 'backend')

from backend.main import SessionLocal, User, School, Video, FactVideoUpload
from sqlalchemy import func

db = SessionLocal()

print("=" * 80)
print("SCHOOLS")
print("=" * 80)
schools = db.query(School).all()
for s in schools:
    print(f"ID: {s.id}, Name: {s.name}, Region: {s.region}, District: {s.district}, Email: {s.contact_email}")

print("\n" + "=" * 80)
print("USERS")
print("=" * 80)
users = db.query(User).all()
for u in users:
    print(f"ID: {u.user_id}, Username: {u.username}, Email: {u.email}, Role: {u.role}, School ID: {u.school_id}")

print("\n" + "=" * 80)
print("VIDEOS")
print("=" * 80)
videos = db.query(Video).all()
print(f"Total videos: {len(videos)}")
for v in videos:
    print(f"ID: {v.id}, School: {v.school_id}, Category: {v.sign_category}, Status: {v.verified_status}, Uploader: {v.uploader_id}")

print("\n" + "=" * 80)
print("VIDEO UPLOADS SUMMARY")
print("=" * 80)
stats = db.query(
    Video.school_id,
    func.count(Video.id).label('total'),
    func.count(Video.verified_status == 'approved').label('approved'),
    func.count(Video.verified_status == 'pending').label('pending'),
    func.count(Video.verified_status == 'rejected').label('rejected'),
).group_by(Video.school_id).all()

for school_id, total, approved, pending, rejected in stats:
    print(f"School {school_id}: Total={total}, Approved={approved}, Pending={pending}, Rejected={rejected}")

db.close()
