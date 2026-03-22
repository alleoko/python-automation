import boto3
import json
import secrets
import string

# Initialize IAM client
iam = boto3.client('iam', region_name='us-east-1')

# ── Configuration ──────────────────────────────────────────
USERS = [
    'john.doe',
    'jane.smith',
    'bob.jones',
    'alice.brown',
    'charlie.wilson'
]

GROUP_NAME = 'DevTeam'

POLICY_DOCUMENT = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*"
            ],
            "Resource": "*"
        }
    ]
}
# ───────────────────────────────────────────────────────────


def generate_password():
    """Generate a secure random password"""
    chars = string.ascii_letters + string.digits + "!@#$%"
    return ''.join(secrets.choice(chars) for _ in range(12))


def create_group():
    """Create IAM group"""
    try:
        iam.create_group(GroupName=GROUP_NAME)
        print(f"✓ Group created: {GROUP_NAME}")
    except iam.exceptions.EntityAlreadyExistsException:
        print(f"⚠️  Group already exists: {GROUP_NAME}")


def create_policy():
    """Create a custom IAM policy"""
    try:
        response = iam.create_policy(
            PolicyName='EC2ReadOnly',
            PolicyDocument=json.dumps(POLICY_DOCUMENT),
            Description='Allows read-only access to EC2'
        )
        policy_arn = response['Policy']['Arn']
        print(f"✓ Policy created: {policy_arn}")
        return policy_arn
    except iam.exceptions.EntityAlreadyExistsException:
        # If policy exists, fetch its ARN
        account_id = boto3.client('sts').get_caller_identity()['Account']
        policy_arn = f"arn:aws:iam::{account_id}:policy/EC2ReadOnly"
        print(f"⚠️  Policy already exists: {policy_arn}")
        return policy_arn


def attach_policy_to_group(policy_arn):
    """Attach policy to the group"""
    iam.attach_group_policy(
        GroupName=GROUP_NAME,
        PolicyArn=policy_arn
    )
    print(f"✓ Policy attached to group: {GROUP_NAME}")


def create_users():
    """Create all IAM users, add to group, set passwords"""
    credentials = []

    for username in USERS:
        # 1. Create user
        try:
            iam.create_user(UserName=username)
            print(f"✓ Created user: {username}")
        except iam.exceptions.EntityAlreadyExistsException:
            print(f"⚠️  User already exists: {username}")

        # 2. Add user to group
        iam.add_user_to_group(
            GroupName=GROUP_NAME,
            UserName=username
        )
        print(f"  └── Added to group: {GROUP_NAME}")

        # 3. Create console password
        password = generate_password()
        iam.create_login_profile(
            UserName=username,
            Password=password,
            PasswordResetRequired=True
        )
        print(f"  └── Password set (must reset on first login)")

        credentials.append({'username': username, 'password': password})

    return credentials


def print_summary(credentials):
    """Print a summary of all created users and passwords"""
    print("\n" + "="*45)
    print("       SETUP COMPLETE - USER CREDENTIALS")
    print("="*45)
    for cred in credentials:
        print(f"  👤 {cred['username']}")
        print(f"     Temp Password: {cred['password']}")
        print()
    print("⚠️  Share these credentials securely!")
    print("   Users must reset password on first login.")
    print("="*45)


def main():
    print("\n🚀 Starting IAM setup...\n")

    # Step 1: Create group
    create_group()

    # Step 2: Create and attach policy
    policy_arn = create_policy()
    attach_policy_to_group(policy_arn)

    # Step 3: Create users
    print()
    credentials = create_users()

    # Step 4: Print summary
    print_summary(credentials)


if __name__ == '__main__':
    main()