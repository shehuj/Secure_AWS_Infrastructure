# How to Upload to Ghost Blog

## Step 1: Get Your Ghost Admin API Key

1. **Log into your Ghost Admin panel:**
   - Go to your Ghost blog admin (usually `https://yourblog.com/ghost`)
   - Log in with your credentials

2. **Navigate to Integrations:**
   - Click on **Settings** (gear icon) in the left sidebar
   - Click on **Integrations** (under "Advanced")

3. **Create a Custom Integration:**
   - Scroll down to "Custom integrations"
   - Click **+ Add custom integration**
   - Name it something like "Blog Uploader" or "API Access"
   - Click **Create**

4. **Copy Your Credentials:**
   You'll see two important pieces of information:
   - **Admin API Key** (long string starting with a timestamp)
   - **API URL** (usually `https://yourblog.com/ghost/api/admin`)

   Save both of these securely!

## Step 2: Option A - Manual Upload via Ghost UI (Easiest)

1. Open the blog post file: `docs/ghost-blog-post.md`
2. Copy all the content
3. In Ghost Admin:
   - Click **Posts** → **New post**
   - Paste the content
   - Add a featured image (optional)
   - Add tags
   - Click **Publish**

## Step 2: Option B - Upload via API (Automated)

### Using Python Script

I've created a Python script for you. First, install the required package:

```bash
pip install requests
```

Then run:

```bash
python docs/upload-to-ghost.py
```

The script will prompt you for:
- Your Ghost blog URL
- Your Admin API Key

### Using cURL (Command Line)

Replace the placeholders with your actual values:

```bash
# Set your credentials
GHOST_URL="https://yourblog.com"
ADMIN_API_KEY="your_admin_api_key_here"

# Upload the post
curl -X POST "${GHOST_URL}/ghost/api/admin/posts/" \
  -H "Authorization: Ghost ${ADMIN_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @docs/ghost-post-payload.json
```

## Step 3: Environment Variables (Recommended for Security)

Instead of hardcoding credentials, use environment variables:

```bash
# In your ~/.bashrc or ~/.zshrc
export GHOST_URL="https://yourblog.com"
export GHOST_ADMIN_KEY="your_admin_api_key_here"

# Then source it
source ~/.bashrc  # or ~/.zshrc
```

## Troubleshooting

### Error: 401 Unauthorized
- Check your Admin API Key is correct
- Ensure you're using the Admin API, not Content API
- Verify the API URL is correct

### Error: 422 Unprocessable Entity
- Check the post format is correct
- Ensure required fields are present
- Validate the markdown formatting

### Error: 403 Forbidden
- Verify you have publishing permissions
- Check if your integration has the right scopes

## Additional Resources

- [Ghost Admin API Documentation](https://ghost.org/docs/admin-api/)
- [Ghost Content API vs Admin API](https://ghost.org/docs/content-api/)
- [Ghost API Authentication](https://ghost.org/docs/admin-api/#authentication)

## Quick Tips

1. **Test First**: Try uploading to a test blog or as a draft first
2. **Backup**: Keep a copy of your blog post locally
3. **Tags**: Add relevant tags after uploading for better SEO
4. **Featured Image**: Add a banner image for better social sharing
5. **Preview**: Always preview before publishing

## Next Steps

Once uploaded, you can:
1. Edit the post in Ghost's editor
2. Add custom HTML/CSS if needed
3. Schedule for future publishing
4. Share on social media
5. Monitor analytics

---

Need help? Check the Ghost documentation or reach out to Ghost support!
