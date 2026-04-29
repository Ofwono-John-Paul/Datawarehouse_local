import requests
import json

BASE_URL = "http://localhost:5000"

# Login with admin account
print("Testing /api/login with admin...")
login_data = {
    "username": "admin",
    "password": "admin",  # Try default password
}
try:
    r = requests.post(f"{BASE_URL}/api/login", json=login_data, timeout=5)
    print(f"Status: {r.status_code}")
    response = r.json()
    print(f"Response: {json.dumps(response, indent=2)}")
    token = response.get("access_token")
    if token:
        print(f"\nAuth Token obtained: {token[:50]}...")
        
        # Try analytics for school 1
        print("\n" + "="*60)
        print("Testing /api/schools/1/analytics...")
        headers = {"Authorization": f"Bearer {token}"}
        try:
            r = requests.get(f"{BASE_URL}/api/schools/1/analytics", headers=headers, timeout=5)
            print(f"Status: {r.status_code}")
            print(f"Response: {json.dumps(r.json(), indent=2)}")
        except Exception as e:
            print(f"ERROR: {e}")
except Exception as e:
    print(f"ERROR: {e}")
