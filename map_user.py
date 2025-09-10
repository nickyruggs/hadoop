from getpass import getpass
import sys
import base64
import os
import json
import argparse
import requests
import urllib3


def get_session(uri):
    """This function gets a session and sets headers, returns session"""
    CREDS = "creds.json"
    if os.path.isfile(CREDS):
        with open(CREDS, "r", encoding="utf-8") as f:
            data = json.load(f)
            user = data["username"]
            p = base64.b64decode(data["password"]).decode("utf-8")
    elif os.path.isfile(CREDS) is False:
        user = input("Please provide your user name? \n").strip()
        print("\nPlease provide the password for your user account...\n")
        p = getpass()

    print(f"\nInitiating a session to {uri} ...\n")
    headers = {"Content-Type": "application/json"}
    payload = {"username": user, "password": p, "services": ["platform", "namespace"]}
    api_session = requests.Session()
    response = api_session.post(
        f"{uri}/session/1/session", json=payload, headers=headers, verify=False
    )
    if response.status_code in [200, 201]:
        print(f"Session to {uri} established.\n")
        api_session.headers["referer"] = uri
        if "isicsrf" in api_session.cookies:
            api_session.headers["X-CSRF-Token"] = api_session.cookies.get("isicsrf")
        return api_session, user
    elif response.status_code not in [200, 201]:
        print(
            f"Session to {uri} not established. Please verify credentials or IP and try again.\n"
        )
        sys.exit(1)


def get_zone_map_rules(api_session, uri, zone):
    """This function will get mapping rules for a zone"""
    response = api_session[0].get(f"{uri}/platform/3/zones/{zone}", verify=False)
    if response.status_code in [200, 201]:
        print(f"\nRetrieved mapping rules for {zone} successfully\n")
        response_str = json.loads(response.content)
        return response_str["zones"][0]["user_mapping_rules"]
    elif response.status_code not in [200, 201]:
        print(f"\nFailed to get mapping rules for {zone}.")
        print(response.content)
    return None


def put_zone_map_rules(api_session, uri, zone, user1, user2, user_mappings):
    """This function will add and set mapping rules for a zone"""
    new_rule = f"{user1} => {user2}"
    user_mappings.append(new_rule)
    json_str = """{"user_mapping_rules": """ + json.dumps(user_mappings) + "}"
    print(json_str)
    response = api_session[0].put(
        f"{uri}/platform/3/zones/{zone}", json=json.loads(json_str), verify=False
    )
    if response.status_code in [200, 201, 204]:
        print(f"\nSet mapping rules for {zone} successfully\n")
    elif response.status_code not in [200, 201, 204]:
        print(f"\nFailed to get mapping rules for {zone}.")
        print(response.status_code)
    return None


def main():
    """This function is the main function"""
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    parser = argparse.ArgumentParser(description="Map a user")
    parser.add_argument("ip", help="Enter a valid IP address for a node.")
    parser.add_argument(
        "user1", help="Enter a valid user in format: DOMAIN\\<SAMACCOUNT>"
    )
    parser.add_argument(
        "user2", help="Enter a valid user in format: DOMAIN\\<SAMACCOUNT>"
    )
    parser.add_argument("zone", help="Enter a valid zone name.")
    args = parser.parse_args()
    user1 = args.user1.strip()
    user2 = args.user2.strip()
    zone = args.zone.strip()

    PORT = 8080
    uri = f"https://{args.ip}:{PORT}"

    api_session = get_session(uri)
    # Check user1 user2 validity
    user_mappings = get_zone_map_rules(api_session, uri, zone)
    put_zone_map_rules(api_session, uri, zone, user1, user2, user_mappings)


if __name__ == "__main__":
    main()

