import requests
import json

base_url = 'http://localhost:8000'

# Login
login_res = requests.post(f"{base_url}/auth/login", json={"email": "test@example.com", "password": "password123"})
if login_res.status_code != 200:
    print("Login failed", login_res.text)
    exit(1)
    
token = login_res.json()['access_token']
headers = {"Authorization": f"Bearer {token}"}

# Scan clean
with open('test_clean.pdf', 'rb') as f:
    res = requests.post(f"{base_url}/scan", files={"file": f}, headers=headers)
    print("Clean response:", res.json())

# Scan malicious
with open('test_malicious.pdf', 'rb') as f:
    res = requests.post(f"{base_url}/scan", files={"file": f}, headers=headers)
    print("Malicious response:", res.json())
