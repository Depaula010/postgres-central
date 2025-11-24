#!/bin/bash
# Script para gerar certificados SSL para PostgreSQL
# Uso: bash generate-ssl-certs.sh

set -e

echo "🔐 Gerando certificados SSL para PostgreSQL..."

# Criar diretórios
mkdir -p ./ssl/{certs,private}
chmod 700 ./ssl/private

# 1. Gerar chave privada da CA (Certificate Authority)
echo "[1/5] Gerando chave privada da CA..."
openssl genrsa -out ./ssl/private/ca.key 4096

# 2. Gerar certificado da CA
echo "[2/5] Gerando certificado da CA..."
openssl req -new -x509 -days 3650 -key ./ssl/private/ca.key \
  -out ./ssl/certs/ca.crt \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=MyCompany/CN=PostgreSQL-CA"

# 3. Gerar chave privada do servidor
echo "[3/5] Gerando chave privada do servidor..."
openssl genrsa -out ./ssl/private/server.key 4096
chmod 600 ./ssl/private/server.key

# 4. Gerar CSR (Certificate Signing Request)
echo "[4/5] Gerando CSR..."
openssl req -new -key ./ssl/private/server.key \
  -out ./ssl/server.csr \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=MyCompany/CN=postgres-central"

# 5. Assinar certificado do servidor com CA
echo "[5/5] Assinando certificado do servidor..."
openssl x509 -req -days 365 \
  -in ./ssl/server.csr \
  -CA ./ssl/certs/ca.crt \
  -CAkey ./ssl/private/ca.key \
  -CAcreateserial \
  -out ./ssl/certs/server.crt

# Limpar arquivos temporários
rm -f ./ssl/server.csr
rm -f ./ssl/certs/ca.srl

# Ajustar permissões (UID 999 = usuário postgres no container)
sudo chown -R 999:999 ./ssl 2>/dev/null || chown -R $USER:$USER ./ssl
chmod 600 ./ssl/private/server.key
chmod 644 ./ssl/certs/*.crt

echo "✅ Certificados SSL gerados com sucesso!"
echo ""
echo "Arquivos criados:"
echo "  - ./ssl/certs/ca.crt (Certificado da CA)"
echo "  - ./ssl/certs/server.crt (Certificado do servidor)"
echo "  - ./ssl/private/server.key (Chave privada do servidor)"
echo ""
echo "⚠️  IMPORTANTE:"
echo "  - NUNCA versione ./ssl/private/*.key no Git"
echo "  - Renove certificados a cada 365 dias"
echo "  - Para conexões de clientes, use: sslmode=require"
