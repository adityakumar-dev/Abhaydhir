#!/usr/bin/env python3
"""
Test script for JWT File Token System
Run this after starting the FastAPI server
"""
import requests
import json

# Configuration
BASE_URL = "http://localhost:8000"
AUTH_TOKEN = "YOUR_AUTH_TOKEN_HERE"  # Replace with actual auth token

def test_get_image_token(user_id: int):
    """Test getting an image token for a user"""
    print(f"\n{'='*60}")
    print(f"TEST: Get Image Token for User {user_id}")
    print(f"{'='*60}")
    
    url = f"{BASE_URL}/tourists/{user_id}/image-token"
    headers = {
        "Authorization": f"Bearer {AUTH_TOKEN}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Success!")
            print(f"User ID: {data['user_id']}")
            print(f"Image Token: {data['image_token'][:50]}...")
            print(f"Image URL: {data['image_url']}")
            return data['image_token']
        else:
            print(f"❌ Error: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Exception: {e}")
        return None

def test_access_user_image(token: str):
    """Test accessing user image with token"""
    print(f"\n{'='*60}")
    print(f"TEST: Access User Image with Token")
    print(f"{'='*60}")
    
    url = f"{BASE_URL}/tourists/user-image/{token}"
    
    try:
        response = requests.get(url)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print(f"✅ Success!")
            print(f"Content-Type: {response.headers.get('Content-Type')}")
            print(f"Content-Length: {len(response.content)} bytes")
            print(f"Cache-Control: {response.headers.get('Cache-Control')}")
            
            # Optionally save the image
            # with open('test_image.jpg', 'wb') as f:
            #     f.write(response.content)
            # print("Image saved as test_image.jpg")
            
            return True
        else:
            print(f"❌ Error: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def test_get_tourist_with_image(user_id: int):
    """Test getting tourist details with image token included"""
    print(f"\n{'='*60}")
    print(f"TEST: Get Tourist Details with Image Token")
    print(f"{'='*60}")
    
    url = f"{BASE_URL}/tourists/{user_id}"
    headers = {
        "Authorization": f"Bearer {AUTH_TOKEN}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Success!")
            
            meta = data.get('tourist', {}).get('meta', {})
            if meta:
                print(f"Image Path: {meta.get('image_path', 'N/A')}")
                print(f"Image Token: {meta.get('image_token', 'N/A')[:50]}...")
                print(f"Image URL: {meta.get('image_url', 'N/A')}")
                print(f"Public Image URL: {meta.get('public_image_url', 'N/A')[:80]}...")
            else:
                print("⚠️  No meta data found")
                
            return True
        else:
            print(f"❌ Error: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def test_expired_token():
    """Test accessing image with expired token"""
    print(f"\n{'='*60}")
    print(f"TEST: Access with Expired Token")
    print(f"{'='*60}")
    
    # This is a sample expired token (for demonstration)
    expired_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJmaWxlX3BhdGgiOiJzdGF0aWMvdXBsb2Fkcy90ZXN0LmpwZyIsImV4cCI6MTYwMDAwMDAwMCwiaWF0IjoxNjAwMDAwMDAwLCJ0eXBlIjoidXNlcl9pbWFnZSIsInVzZXJfaWQiOjEyM30.invalid"
    
    url = f"{BASE_URL}/tourists/user-image/{expired_token}"
    
    try:
        response = requests.get(url)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 403:
            print(f"✅ Correctly rejected expired token")
            print(f"Error Message: {response.json().get('detail', 'N/A')}")
            return True
        else:
            print(f"⚠️  Unexpected response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def test_invalid_token():
    """Test accessing image with invalid token"""
    print(f"\n{'='*60}")
    print(f"TEST: Access with Invalid Token")
    print(f"{'='*60}")
    
    invalid_token = "invalid-token-12345"
    url = f"{BASE_URL}/tourists/user-image/{invalid_token}"
    
    try:
        response = requests.get(url)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 403:
            print(f"✅ Correctly rejected invalid token")
            print(f"Error Message: {response.json().get('detail', 'N/A')}")
            return True
        else:
            print(f"⚠️  Unexpected response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("JWT FILE TOKEN SYSTEM - API TESTS")
    print("="*60)
    print(f"Base URL: {BASE_URL}")
    print(f"Auth Token: {'SET' if AUTH_TOKEN != 'YOUR_AUTH_TOKEN_HERE' else 'NOT SET'}")
    
    if AUTH_TOKEN == "YOUR_AUTH_TOKEN_HERE":
        print("\n⚠️  WARNING: Please set AUTH_TOKEN in the script before running tests")
        print("You can get an auth token by logging in through the API")
        return
    
    # Test with a sample user ID (replace with actual user ID from your database)
    TEST_USER_ID = 1
    
    # Run tests
    print(f"\n⚠️  Using User ID: {TEST_USER_ID} (change this to a valid user ID)")
    
    # Test 1: Get tourist details with image token
    test_get_tourist_with_image(TEST_USER_ID)
    
    # Test 2: Get image token directly
    token = test_get_image_token(TEST_USER_ID)
    
    # Test 3: Access image with token
    if token:
        test_access_user_image(token)
    
    # Test 4: Test expired token handling
    test_expired_token()
    
    # Test 5: Test invalid token handling
    test_invalid_token()
    
    print("\n" + "="*60)
    print("TESTS COMPLETED")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
