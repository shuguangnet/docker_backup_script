#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import json
import hmac
import hashlib
import requests
import os


def load_callback_secret(config_path):
    """Load callback_secret from the configuration file."""
    try:
        with open(config_path, "r") as f:
            for line in f:
                if line.startswith("callback_secret="):
                    # Remove the 'callback_secret=' prefix and any surrounding whitespace or quotes
                    secret = line[len("callback_secret=") :].strip().strip("\"'")
                    return secret
    except FileNotFoundError:
        print(f"Error: Configuration file '{config_path}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading configuration file: {e}")
        sys.exit(1)

    print("Error: 'callback_secret' not found in configuration file.")
    sys.exit(1)


def main():
    # Define the path to the configuration file
    config_path = os.path.join(os.path.dirname(__file__), "..", "..", "backup.conf")

    # Load the callback secret
    callback_secret = load_callback_secret(config_path)

    # Get command line arguments
    args = sys.argv[1:]

    # Create the JSON payload
    payload = {"args": args}
    json_data = json.dumps(payload, separators=(",", ":"))

    # Generate HMAC-SHA256 signature
    signature = hmac.new(
        callback_secret.encode("utf-8"), json_data.encode("utf-8"), hashlib.sha256
    ).hexdigest()

    # Prepare headers
    headers = {"Content-Type": "application/json", "X-Signature": signature}

    # Send POST request
    url = "http://localhost:47731/backup"
    try:
        response = requests.post(url, data=json_data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response Body: {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"Error sending request: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
