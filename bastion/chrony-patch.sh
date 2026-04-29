#!/bin/bash

# Create chrony config
cat > /tmp/chrony.conf << 'EOF'
server 192.168.171.40 iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

# Encode to base64
BASE64=$(base64 -w0 /tmp/chrony.conf)

# Patch each ignition file using python
for f in /var/lib/matchbox/ignition/*.ign; do
    echo "Patching $f..."
    python3 << PYEOF
import json

with open('$f', 'r') as file:
    data = json.load(file)

# Ensure storage and files exist
if 'storage' not in data:
    data['storage'] = {}
if 'files' not in data['storage']:
    data['storage']['files'] = []

# Remove existing chrony.conf if present
data['storage']['files'] = [
    x for x in data['storage']['files']
    if x.get('path') != '/etc/chrony.conf'
]

# Add chrony config
data['storage']['files'].append({
    'path': '/etc/chrony.conf',
    'contents': {
        'source': 'data:text/plain;base64,$BASE64'
    },
    'mode': 420,
    'overwrite': True
})

with open('$f', 'w') as file:
    json.dump(data, file)

print('Done: $f')
PYEOF
done

# Restart matchbox
systemctl restart matchbox
echo "Matchbox restarted"

# Configure bastion as NTP server
echo "Configuring bastion as NTP server..."
grep -q "allow 192.168.171.0/24" /etc/chrony.conf || \
    echo "allow 192.168.171.0/24" >> /etc/chrony.conf
systemctl enable chronyd --now
systemctl restart chronyd
echo "Bastion NTP configured"
chronyc tracking