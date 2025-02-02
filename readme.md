# CampNet Auto-Login Script for macOS

A script that automatically authenticates with BITS Pilani's CampNet WiFi network, maintaining persistent connectivity through network changes and daily data limit resets.

## Features
- Automatic CampNet authentication on network connect
- Handles daily credential resets (1GB data limit)
- Persistent background operation
- WiFi reconnect resilience
- Secure credential storage (user-provided)

## Prerequisites
- Python 3.x
- macOS
- Valid BITS credentials in config file

## Installation
1. Clone repository:
```bash
git clone https://github.com/yourusername/campnet-auto-login.git
cd campnet-auto-login
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Create credentials file:
```bash
touch credentials.json
```

## Configuration
1. Edit `credentials.json` with your BITS credentials:
```json
{
  "username": "f20XXXXXX@bits-pilani.ac.in",
  "password": "your_current_password"
}
```

2. (Recommended) Encrypt credentials file using macOS Keychain

## Usage
```bash
python campnet_auto_login.py
```

For background operation:
```bash
nohup python campnet_auto_login.py > campnet.log 2>&1 &
```

## Security Notes
- Never commit your credentials file to version control
- Credentials are stored locally only
- Recommended to rotate passwords according to BITS policies

## Troubleshooting
- Verify credentials are correct
- Check internet connection status
- Monitor `campnet.log` for errors
- Ensure script is running in background:
```bash
pgrep -f campnet_auto_login.py
```

## License
MIT License - see [LICENSE](LICENSE) for details
