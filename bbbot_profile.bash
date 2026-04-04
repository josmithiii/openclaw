#!/bin/bash
# Switch BBBot tools profile and restart the gateway
# Usage: bbbot_profile.bash [messaging|coding|minimal|full]

PROFILE="${1:-messaging}"
CONFIG="$HOME/.openclaw/openclaw.json"

if ! echo "$PROFILE" | grep -qE '^(minimal|coding|messaging|full)$'; then
  echo "Usage: $0 [minimal|coding|messaging|full]"
  echo "Current: $(python3 -c "import json; print(json.load(open('$CONFIG'))['tools']['profile'])")"
  exit 1
fi

python3 -c "
import json
cfg = json.load(open('$CONFIG'))
cfg['tools']['profile'] = '$PROFILE'
json.dump(cfg, open('$CONFIG', 'w'), indent=2)
print('Tools profile set to: $PROFILE')
"

echo "Restart the container to apply: dcoc restart"
