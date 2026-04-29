import requests
import json

BASE_URL = "http://localhost:5000"

# Login with test user
print("Testing /api/login with testuser...")
login_data = {
    "username": "testuser",
    "password": "password123",
}
try:
    r = requests.post(f"{BASE_URL}/api/login", json=login_data, timeout=5)
    print(f"Status: {r.status_code}")
    response = r.json()
    print(f"Response: {json.dumps(response, indent=2)}")
    token = response.get("access_token")
    if token:
        print(f"\n✓ Auth Token obtained: {token[:50]}...")
        school_id = response.get("user", {}).get("school", {}).get("id", 1)
        print(f"School ID: {school_id}")
        
        # Try analytics for this school
        print("\n" + "="*60)
        print(f"Testing /api/schools/{school_id}/analytics...")
        headers = {"Authorization": f"Bearer {token}"}
        try:
            r = requests.get(f"{BASE_URL}/api/schools/{school_id}/analytics", headers=headers, timeout=5)
            print(f"Status: {r.status_code}")
            if r.status_code == 200:
                print("✓ Analytics endpoint WORKING!")
                print(f"Response: {json.dumps(r.json(), indent=2)}")
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
