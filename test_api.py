#!/usr/bin/env python3
"""Test API endpoints locally"""
import requests
import json

BASE_URL = "http://localhost:5000"

# Test health
print("Testing /api/health...")
try:
    r = requests.get(f"{BASE_URL}/api/health", timeout=2)
    print(f"Status: {r.status_code}")
    print(f"Response: {r.json()}\n")
except Exception as e:
    print(f"ERROR: {e}\n")

# Test categories
print("Testing /api/meta/categories...")
try:
    r = requests.get(f"{BASE_URL}/api/meta/categories", timeout=2)
    print(f"Status: {r.status_code}")
    print(f"Response: {r.json()}\n")
except Exception as e:
    print(f"ERROR: {e}\n")

# Register a test school with built-in user
print("Testing /api/register-school...")
school_data = {
    "school_name": "Test School ABC",
    "region": "Central",
    "district": "Kampala",
    "contact_email": "testschool@school.ug",
    "username": "schooladmin1",
    "password": "TestPass123!",
    "phone": "0123456789",
    "address": "123 Main St",
    "school_type": "Primary",
    "deaf_students": 10,
}
try:
    r = requests.post(f"{BASE_URL}/api/register-school", json=school_data, timeout=5)
    print(f"Status: {r.status_code}")
    response = r.json()
    print(f"Response: {response}")
    school_id = response.get("school_id", 1)
    print(f"Created School ID: {school_id}\n")
except Exception as e:
    print(f"ERROR (school registration): {e}")
    print(f"Trying with existing school...\n")
    school_id = 1

# Now login to get token
print("Testing /api/login...")
login_data = {
    "username": "schooladmin1",
    "password": "TestPass123!",
}
token = None
try:
    r = requests.post(f"{BASE_URL}/api/login", json=login_data, timeout=5)
    print(f"Status: {r.status_code}")
    response = r.json()
    print(f"Response: {json.dumps(response, indent=2)}")
    token = response.get("access_token")
    school_id = response.get("user", {}).get("school", {}).get("id", school_id)
    print(f"Auth Token: {token}")
    print(f"School ID from login: {school_id}\n")
except Exception as e:
    print(f"ERROR (login): {e}\n")

# Test analytics endpoint with auth
if token:
    print(f"Testing /api/schools/{school_id}/analytics with auth...")
    headers = {"Authorization": f"Bearer {token}"}
    try:
        r = requests.get(f"{BASE_URL}/api/schools/{school_id}/analytics", headers=headers, timeout=5)
        print(f"Status: {r.status_code}")
        print(f"Response: {json.dumps(r.json(), indent=2)}\n")
    except Exception as e:
        print(f"ERROR: {e}\n")

# Test videos list
if token:
    print(f"Testing /api/videos with auth...")
    headers = {"Authorization": f"Bearer {token}"}
    try:
        r = requests.get(f"{BASE_URL}/api/videos", headers=headers, timeout=5)
        print(f"Status: {r.status_code}")
        response = r.json()
        print(f"Total videos: {response.get('total')}")
        print(f"Videos count in response: {len(response.get('videos', []))}")
        if response.get('videos'):
            print(f"First video: {json.dumps(response['videos'][0], indent=2)}\n")
    except Exception as e:
        print(f"ERROR: {e}\n")
