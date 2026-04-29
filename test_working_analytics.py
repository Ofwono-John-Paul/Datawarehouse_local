import requests
import json

BASE_URL = "http://localhost:5000"

# Try login with testuser1 (which exists in the database)
print("Testing /api/login with testuser1...")
login_data = {
    "username": "testuser1",
    "password": "TestPass123!",  # This was the password from test_api.py
}
try:
    r = requests.post(f"{BASE_URL}/api/login", json=login_data, timeout=5)
    print(f"Status: {r.status_code}")
    response = r.json()
    print(f"Response: {json.dumps(response, indent=2)}")
    token = response.get("access_token")
    if token:
        print(f"\n✓ Auth Token obtained: {token[:50]}...")
        school_id = response.get("user", {}).get("school", {}).get("id") or response.get("user", {}).get("id")
        print(f"User ID: {response.get('user', {}).get('id')}")
        print(f"School info: {response.get('user', {}).get('school')}")
        
        # Try analytics for school 1 (the first school in the system)
        print("\n" + "="*60)
        print("Testing /api/schools/1/analytics...")
        headers = {"Authorization": f"Bearer {token}"}
        try:
            r = requests.get(f"{BASE_URL}/api/schools/1/analytics", headers=headers, timeout=5)
            print(f"Status: {r.status_code}")
            if r.status_code == 200:
                print("✓ Analytics endpoint WORKING!")
                response = r.json()
                print(f"Response keys: {list(response.keys())}")
                print(f"Total uploads: {response.get('total_uploads')}")
                print(f"Approved: {response.get('approved')}")
                print(f"Pending: {response.get('pending')}")
            else:
                print(f"✗ Error: {r.json()}")
        except Exception as e:
            print(f"✗ ERROR: {e}")
            import traceback
            traceback.print_exc()
    else:
        print("✗ No token received")
except Exception as e:
    print(f"✗ ERROR: {e}")
    import traceback
    traceback.print_exc()
