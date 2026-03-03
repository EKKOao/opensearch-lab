#!/bin/bash
set -e
echo "--- Configuring OpenSearch Cluster, Security, and Keystore ---"

OS_HOME="/mnt/opensearch/home"
CONFIG_DIR="$OS_HOME/config"
YML_FILE="$CONFIG_DIR/opensearch.yml"
HOSTNAME=$(hostname)
TOOLS_DIR="$OS_HOME/plugins/opensearch-security/tools"
USERS_FILE="$OS_HOME/config/opensearch-security/internal_users.yml"
KEYSTORE_BIN="$OS_HOME/bin/opensearch-keystore"

NEW_PASSWORD="password123456"
CERT_PASSWORD="changeit"

# ==========================================
# 1. OPENSEARCH.YML (No plaintext passwords)
# ==========================================
cat <<EOF > $YML_FILE
cluster.name: os-cluster
node.name: ${HOSTNAME}
path.data: /mnt/opensearch/data
path.logs: /mnt/opensearch/logs
path.repo: ["/mnt/opensearch/backup"]

network.host: [_local_, "_prod_"]
http.port: 9200

discovery.seed_hosts: ["192.168.56.11", "192.168.56.12", "192.168.56.13"]
cluster.initial_cluster_manager_nodes: ["os1", "os2", "os3"]
bootstrap.memory_lock: true

# --- Security Plugin Configuration (PKCS12 FORMAT) ---
plugins.security.ssl.transport.enabled: true
plugins.security.ssl.transport.enforce_hostname_verification: false
plugins.security.ssl.transport.keystore_filepath: certs/node.p12
plugins.security.ssl.transport.truststore_filepath: certs/truststore.p12

plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.keystore_filepath: certs/node.p12
plugins.security.ssl.http.truststore_filepath: certs/truststore.p12

plugins.security.allow_unsafe_democertificates: true
plugins.security.allow_default_init_securityindex: true

# Define the Admin Cert DN 
plugins.security.authcz.admin_dn:
  - "CN=admin,OU=Admin,O=Lab,L=Paris,C=FR"

# Define the Node Cert DNs 
plugins.security.nodes_dn:
  - "CN=os1,OU=Node,O=Lab,L=Paris,C=FR"
  - "CN=os2,OU=Node,O=Lab,L=Paris,C=FR"
  - "CN=os3,OU=Node,O=Lab,L=Paris,C=FR"
EOF

chown 1122:1122 $YML_FILE
chmod 660 $YML_FILE

# ==========================================
# 2. OPENSEARCH KEYSTORE (Secure Passwords)
# ==========================================
echo "Configuring secure keystore..."

if [ ! -f "$CONFIG_DIR/opensearch.keystore" ]; then
    $KEYSTORE_BIN create
fi

## Clean up the old, invalid non-secure keys if they exist from a previous run
#$KEYSTORE_BIN remove plugins.security.ssl.transport.keystore_password || true
#$KEYSTORE_BIN remove plugins.security.ssl.transport.truststore_password || true
#$KEYSTORE_BIN remove plugins.security.ssl.http.keystore_password || true
#$KEYSTORE_BIN remove plugins.security.ssl.http.truststore_password || true

# Use a temporary file to pipe the password safely
PASS_FILE="/tmp/cert_pass"
echo -n "$CERT_PASSWORD" > "$PASS_FILE"

add_to_keystore() {
    local key_name=$1
    if ! $KEYSTORE_BIN list | grep -q "^${key_name}$"; then
        $KEYSTORE_BIN add --stdin "$key_name" < "$PASS_FILE"
    fi
}

# Add the keys WITH the required '_secure' suffix
add_to_keystore "plugins.security.ssl.transport.keystore_password_secure"
add_to_keystore "plugins.security.ssl.transport.truststore_password_secure"
add_to_keystore "plugins.security.ssl.http.keystore_password_secure"
add_to_keystore "plugins.security.ssl.http.truststore_password_secure"

# Cleanup temp password file and secure the keystore file
rm -f "$PASS_FILE"
chown 1122:1122 "$CONFIG_DIR/opensearch.keystore"
chmod 600 "$CONFIG_DIR/opensearch.keystore"

# ==========================================
# 3. INTERNAL USERS (Admin Hash)
# ==========================================
echo "Updating internal_users.yml..."

if [ ! -f "$USERS_FILE" ]; then
    USERS_FILE="$OS_HOME/plugins/opensearch-security/securityconfig/internal_users.yml"
fi

chmod +x "$TOOLS_DIR/hash.sh"

export JAVA_HOME="$OS_HOME/jdk" 
HASHED_PASSWORD=$("$TOOLS_DIR/hash.sh" -p "$NEW_PASSWORD")

sed -i "/^admin:/,/hash:/ s|hash: .*|hash: \"$HASHED_PASSWORD\"|" "$USERS_FILE"

chown 1122:1122 "$USERS_FILE"
chmod 600 "$USERS_FILE"

echo "Successfully updated admin hash in internal_users.yml"

# ==========================================
# 4. START AND VERIFY SERVICE
# ==========================================
echo "Restarting OpenSearch service..."
systemctl restart opensearch

sleep 15
if systemctl is-active --quiet opensearch; then
    PROD_IP=$(ip -4 addr show prod | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo "SUCCESS: OpenSearch is running on $HOSTNAME binding to prod ($PROD_IP)"
else
    echo "FAILED: OpenSearch service did not start correctly."
    exit 1
fi