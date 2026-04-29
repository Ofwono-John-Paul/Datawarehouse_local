import requests
import json

BASE_URL = "http://localhost:5000"

# Login with testuser1
print("Logging in with testuser1...")
login_data = {"username": "testuser1", "password": "TestPass123!"}
r = requests.post(f"{BASE_URL}/api/login", json=login_data, timeout=5)
token = r.json().get("access_token")
print(f"✓ Got token: {token[:40]}...")

# Check what schools exist by trying to access school 1
print("\nTesting /api/schools/1/analytics...")
headers = {"Authorization": f"Bearer {token}"}
r = requests.get(f"{BASE_URL}/api/schools/1/analytics", headers=headers, timeout=5)
print(f"Status: {r.status_code}")
if r.status_code == 200:
    print("✓✓✓ Analytics endpoint WORKING! ✓✓✓")
    response = r.json()
    print(f"\nResponse:")
    print(json.dumps(response, indent=2))
else:
    print(f"Error: {r.json()}")
