# Security Guidelines

## Environment Variables

This repository uses environment variables to prevent hardcoded credentials in source code.

### Required Environment Variables

Before using any scripts, set these environment variables:

```bash
# Copy .env.example to .env and fill in your values
cp .env.example .env

# Edit .env with your actual credentials
nano .env

# Source the environment file
source .env
```

### Security Best Practices

1. **Never commit `.env` files** - They are excluded by `.gitignore`
2. **Use strong, unique tokens** - Generate them through your Beszel hub admin interface
3. **Rotate credentials regularly** - Especially if they may have been exposed
4. **Limit token permissions** - Use universal tokens only for agent registration
5. **Monitor access logs** - Check for unauthorized connection attempts

### Getting Your Credentials

1. **Hub URL**: Your Beszel monitoring hub URL
2. **Universal Token**: Generate via hub admin interface at `/admin/beszel/universal-tokens`
3. **SSH Public Key**: Extract from hub's `/beszel_data/id_ed25519.pub` file

### Emergency Response

If credentials are accidentally committed:

1. **Immediately rotate all tokens** via hub admin
2. **Change admin passwords**
3. **Review git history** and clean if necessary
4. **Check access logs** for unauthorized access
5. **Update all agents** with new credentials

## File Permissions

Ensure proper file permissions on sensitive files:

```bash
chmod 600 .env
chmod 700 ~/.ssh/
chmod 600 ~/.ssh/authorized_keys
```

## Network Security

- Use HTTPS for hub communication
- Consider VPN for agent-hub connections
- Firewall rules to restrict access
- Regular security updates on all systems