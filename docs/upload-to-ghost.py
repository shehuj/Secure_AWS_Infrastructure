#!/usr/bin/env python3
"""
Ghost Blog Uploader
Upload blog posts to Ghost via the Admin API
"""

import os
import json
import jwt
import requests
from datetime import datetime, timedelta
from pathlib import Path

def generate_jwt_token(api_key):
    """Generate JWT token for Ghost Admin API authentication"""
    # Split the key into ID and secret
    key_id, secret = api_key.split(':')

    # Prepare JWT claims
    iat = int(datetime.now().timestamp())

    payload = {
        'iat': iat,
        'exp': iat + 5 * 60,  # Token expires in 5 minutes
        'aud': '/admin/'
    }

    # Generate token
    token = jwt.encode(payload, bytes.fromhex(secret), algorithm='HS256', headers={'kid': key_id})

    return token if isinstance(token, str) else token.decode('utf-8')

def read_blog_post(file_path):
    """Read the blog post markdown file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()

def create_ghost_post(ghost_url, api_key, title, content, tags=None, featured=False, status='draft'):
    """
    Create a new post in Ghost

    Args:
        ghost_url: Your Ghost blog URL (e.g., https://yourblog.com)
        api_key: Ghost Admin API key
        title: Post title
        content: Post content in markdown
        tags: List of tag names
        featured: Whether to feature the post
        status: 'draft' or 'published'
    """
    try:
        # Generate JWT token
        token = generate_jwt_token(api_key)

        # Prepare API endpoint
        api_url = f"{ghost_url}/ghost/api/admin/posts/"

        # Prepare headers
        headers = {
            'Authorization': f'Ghost {token}',
            'Content-Type': 'application/json'
        }

        # Prepare post data
        post_data = {
            'posts': [{
                'title': title,
                'markdown': content,
                'status': status,
                'featured': featured,
            }]
        }

        # Add tags if provided
        if tags:
            post_data['posts'][0]['tags'] = [{'name': tag} for tag in tags]

        # Make the request
        print(f"📤 Uploading post to {ghost_url}...")
        response = requests.post(api_url, headers=headers, json=post_data)

        # Check response
        if response.status_code == 201:
            post_info = response.json()['posts'][0]
            print(f"✅ Post created successfully!")
            print(f"   Title: {post_info['title']}")
            print(f"   Status: {post_info['status']}")
            print(f"   URL: {post_info['url']}")
            return post_info
        else:
            print(f"❌ Failed to create post: {response.status_code}")
            print(f"   Response: {response.text}")
            return None

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return None

def main():
    """Main function to upload blog post"""
    print("=" * 60)
    print("Ghost Blog Uploader")
    print("=" * 60)
    print()

    # Get credentials from environment variables or prompt
    ghost_url = os.getenv('GHOST_URL')
    if not ghost_url:
        ghost_url = input("Enter your Ghost blog URL (e.g., https://yourblog.com): ").strip()

    admin_api_key = os.getenv('GHOST_ADMIN_KEY')
    if not admin_api_key:
        print("\nEnter your Ghost Admin API Key")
        print("(Format: ID:SECRET - get this from Ghost Admin > Settings > Integrations)")
        admin_api_key = input("API Key: ").strip()

    # Read the blog post
    blog_file = Path(__file__).parent / 'ghost-blog-post.md'

    if not blog_file.exists():
        print(f"❌ Blog post file not found: {blog_file}")
        return

    print(f"\n📖 Reading blog post from {blog_file.name}...")
    content = read_blog_post(blog_file)

    # Extract title from content (first line starting with #)
    lines = content.split('\n')
    title = "anotherDAY, ANOTHERdollar!"
    for line in lines:
        if line.startswith('# '):
            title = line[2:].strip()
            break

    print(f"   Title: {title}")
    print(f"   Length: {len(content)} characters")

    # Ask for publication status
    print("\nPublication options:")
    print("1. Draft (saves as draft)")
    print("2. Published (publishes immediately)")
    choice = input("Choose option (1 or 2) [default: 1]: ").strip() or "1"

    status = 'draft' if choice == '1' else 'published'

    # Define tags
    tags = [
        'DevOps',
        'AWS',
        'Terraform',
        'Ansible',
        'CI/CD',
        'Harness',
        'Infrastructure',
        'Automation',
        'Cloud Engineering'
    ]

    print(f"\n🏷️  Tags: {', '.join(tags)}")

    # Confirm before uploading
    print("\n" + "=" * 60)
    print("Ready to upload!")
    print(f"  Blog: {ghost_url}")
    print(f"  Title: {title}")
    print(f"  Status: {status}")
    print(f"  Tags: {len(tags)} tags")
    print("=" * 60)

    confirm = input("\nProceed with upload? (y/N): ").strip().lower()

    if confirm == 'y':
        # Create the post
        result = create_ghost_post(
            ghost_url=ghost_url,
            api_key=admin_api_key,
            title=title,
            content=content,
            tags=tags,
            featured=False,
            status=status
        )

        if result:
            print("\n✨ Success! Your blog post has been uploaded.")
            print(f"\n🔗 View at: {result['url']}")

            if status == 'draft':
                print("\n💡 Tip: Visit Ghost Admin to preview and publish when ready.")
        else:
            print("\n❌ Upload failed. Check the error messages above.")
    else:
        print("\n❌ Upload cancelled.")

    print("\n" + "=" * 60)

if __name__ == '__main__':
    # Check if PyJWT is installed
    try:
        import jwt
    except ImportError:
        print("❌ PyJWT library not found!")
        print("\nInstall it with:")
        print("  pip install PyJWT")
        print("\nOr install all requirements:")
        print("  pip install PyJWT requests")
        exit(1)

    main()
