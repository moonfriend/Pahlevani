# Deploying to a VPS

Run this on the VPS itself, over SSH. It sets the bot up as a systemd service that
survives reboots and restarts on crash.

## 1. Generate a deploy key on the VPS (read-only, scoped to this repo)

```bash
ssh-keygen -t ed25519 -C "pahlevani-vps-deploy" -f ~/.ssh/pahlevani_deploy -N ""
cat ~/.ssh/pahlevani_deploy.pub
```

Copy the printed public key. On GitHub: repo → **Settings → Deploy keys → Add deploy key**
→ paste it, leave **"Allow write access" unchecked** — the VPS only needs to pull.

## 2. Point git at that key for this host

```bash
cat >> ~/.ssh/config <<'EOF'
Host github-pahlevani
  HostName github.com
  User git
  IdentityFile ~/.ssh/pahlevani_deploy
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config
```

## 3. Clone and install `uv`

```bash
git clone github-pahlevani:moonfriend/Pahlevani.git ~/Pahlevani
curl -LsSf https://astral.sh/uv/install.sh | sh
cd ~/Pahlevani/challenge_bot
~/.local/bin/uv sync
```

## 4. Set up secrets

Never commit these — create `.env` fresh on the box:

```bash
cp .env.example .env
nano .env   # fill in TELEGRAM_BOT_TOKEN, SUPABASE_URL, SUPABASE_KEY
chmod 600 .env
```

`SUPABASE_KEY` must be the **service-role key** (see the main `README.md` for why).

## 5. Create the systemd service

`sudo nano /etc/systemd/system/challenge-bot.service`:

```ini
[Unit]
Description=Challenge Bot (Telegram)
After=network.target

[Service]
Type=simple
User=YOUR_VPS_USER
WorkingDirectory=/home/YOUR_VPS_USER/Pahlevani/challenge_bot
EnvironmentFile=/home/YOUR_VPS_USER/Pahlevani/challenge_bot/.env
ExecStart=/home/YOUR_VPS_USER/.local/bin/uv run python main.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Replace `YOUR_VPS_USER` throughout, and don't run this as root — use whichever non-root
account you SSH'd in as.

## 6. Enable and start it

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now challenge-bot
sudo systemctl status challenge-bot
journalctl -u challenge-bot -f   # watch logs live
```

## Updating after new commits land on `main`

```bash
cd ~/Pahlevani && git pull
cd challenge_bot && ~/.local/bin/uv sync
sudo systemctl restart challenge-bot
```

## New migrations

If a deploy includes a new `supabase/migrations/NNNN_*.sql` file, apply it to the Supabase
project (SQL Editor, or however you've been applying them) *before* restarting the service
— the bot expects the schema it's running against to already exist.

## Only one bot process per token

Telegram doesn't allow two processes to long-poll the same bot token at once — they'll
fight over updates and both misbehave. Before starting the VPS service, make sure no other
`python main.py` process (e.g. on your dev machine) is still running against the same
`TELEGRAM_BOT_TOKEN`.
