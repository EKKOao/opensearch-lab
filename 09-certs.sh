#!/bin/bash
set -e

OS_HOME="/mnt/opensearch/home"
NFS_PATH="/mnt/opensearch/backup/certs"
LOCAL_CERTS="$OS_HOME/config/certs"
HOSTNAME=$(hostname)
# Default password for the .p12 files
KS_PASS="changeit"

# IP Calc for Subject Alternative Names (SAN)
NODE_NUM=$(echo $HOSTNAME | tr -dc '0-9')
NODE_IP="192.168.56.$((10 + NODE_NUM))"

mkdir -p "$NFS_PATH"
mkdir -p "$LOCAL_CERTS"

# === CA & ADMIN GENERATION (os1 only) ===
if [ "$HOSTNAME" == "os1" ]; then
    if [ ! -f "$NFS_PATH/root-ca.pem" ]; then
        echo "Generating Root CA..."
        openssl genrsa -out "$NFS_PATH/root-ca-key.pem" 2048
        openssl req -new -x509 -sha256 -key "$NFS_PATH/root-ca-key.pem" \
            -subj "/C=FR/L=Paris/O=Lab/OU=CA/CN=RootCA" -out "$NFS_PATH/root-ca.pem" -days 3650

        echo "Generating Admin Cert..."
        openssl genrsa -out "$NFS_PATH/admin-key.pem" 2048
        openssl req -new -key "$NFS_PATH/admin-key.pem" \
            -subj "/C=FR/L=Paris/O=Lab/OU=Admin/CN=admin" -out "$NFS_PATH/admin.csr"
        openssl x509 -req -in "$NFS_PATH/admin.csr" -CA "$NFS_PATH/root-ca.pem" -CAkey "$NFS_PATH/root-ca-key.pem" -CAcreateserial -sha256 -out "$NFS_PATH/admin.pem" -days 3650
        
        echo "Bundling Admin into PKCS12 (.p12)..."
        openssl pkcs12 -export -in "$NFS_PATH/admin.pem" -inkey "$NFS_PATH/admin-key.pem" \
            -certfile "$NFS_PATH/root-ca.pem" -out "$NFS_PATH/admin.p12" -name admin -passout pass:$KS_PASS
            
        # Clean up Admin PEMs as they are now securely inside the .p12
        rm -f "$NFS_PATH/admin.pem" "$NFS_PATH/admin-key.pem" "$NFS_PATH/admin.csr"
    fi
    chmod 777 "$NFS_PATH"/*
fi

# === BARRIER: Wait for CA to be ready on NFS ===
while [ ! -f "$NFS_PATH/root-ca.pem" ]; do sleep 2; done

# === NODE CERT GENERATION (All Nodes) ===
if [ ! -f "$LOCAL_CERTS/node.p12" ]; then
    echo "Generating Node Cert for $HOSTNAME..."
    
    # 1. Generate Node Private Key
    openssl genrsa -out "$LOCAL_CERTS/node-key.pem" 2048
    
    # 2. Generate CSR
    openssl req -new -key "$LOCAL_CERTS/node-key.pem" \
        -subj "/C=FR/L=Paris/O=Lab/OU=Node/CN=$HOSTNAME" -out "$LOCAL_CERTS/node.csr"
    
    # 3. Create Extension file for SAN
    echo "subjectAltName=DNS:$HOSTNAME,DNS:localhost,IP:$NODE_IP,IP:127.0.0.1" > "$LOCAL_CERTS/node.ext"

    # 4. Sign Node Cert with CA
    openssl x509 -req -in "$LOCAL_CERTS/node.csr" -CA "$NFS_PATH/root-ca.pem" -CAkey "$NFS_PATH/root-ca-key.pem" -CAcreateserial -sha256 -out "$LOCAL_CERTS/node.pem" -days 3650 -extfile "$LOCAL_CERTS/node.ext"
    
    # 5. Bundle Node Cert and Key into PKCS12 Keystore
    echo "Bundling Node into PKCS12 (.p12)..."
    openssl pkcs12 -export -in "$LOCAL_CERTS/node.pem" -inkey "$LOCAL_CERTS/node-key.pem" \
        -certfile "$NFS_PATH/root-ca.pem" -out "$LOCAL_CERTS/node.p12" -name $HOSTNAME -passout pass:$KS_PASS
        
    # 6. Create a Truststore containing the Root CA (Using OpenSearch's bundled Java)
    echo "Creating Truststore..."
    $OS_HOME/jdk/bin/keytool -importcert -keystore "$LOCAL_CERTS/truststore.p12" -storetype PKCS12 \
        -storepass $KS_PASS -alias root-ca -file "$NFS_PATH/root-ca.pem" -noprompt
    
    # Cleanup temp files and raw PEM keys
    rm -f "$LOCAL_CERTS"/*.csr "$LOCAL_CERTS"/*.ext "$LOCAL_CERTS"/*.pem
fi

# Secure local certs
chown -R 1122:1122 "$LOCAL_CERTS"
chmod 600 "$LOCAL_CERTS"/*.p12
chmod 700 "$LOCAL_CERTS"

# === CLEANUP TRIGGER ===
touch "$NFS_PATH/$HOSTNAME.cert_done"
DONE_COUNT=$(find "$NFS_PATH" -maxdepth 1 -name "*.cert_done" | wc -l)

if [ "$DONE_COUNT" -ge 3 ]; then
    # Delete the CA private key to secure the cluster!
    rm -f "$NFS_PATH/root-ca-key.pem"
    rm -f "$NFS_PATH"/*.cert_done
fi