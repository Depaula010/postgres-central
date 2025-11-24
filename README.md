# PostgreSQL - Configuração Segura

Este diretório contém a configuração segura do banco de dados PostgreSQL para o projeto AppControleFinanceiro.

## 🔐 Vulnerabilidades Corrigidas

### Antes (INSEGURO):
```yaml
environment:
  - POSTGRES_USER=admin
  - POSTGRES_PASSWORD=senha123  # ❌ EXPOSTA
ports:
  - "5432:5432"  # ❌ EXPOSTO PUBLICAMENTE
```

### Depois (SEGURO):
```yaml
environment:
  - POSTGRES_USER=${DB_USER}  # ✅ Variável de ambiente
  - POSTGRES_PASSWORD=${DB_PASSWORD}  # ✅ Senha forte
ports:
  - "127.0.0.1:5432:5432"  # ✅ Apenas localhost
```

---

## 📁 Estrutura do Projeto

```
postgres-central/
├── docker-compose.yml          # Configuração segura do container
├── .env                        # Secrets (NÃO VERSIONAR)
├── .env.example                # Template de configuração
├── .gitignore                  # Arquivos a ignorar
├── config/
│   ├── postgresql.conf         # Configurações do PostgreSQL
│   └── pg_hba.conf            # Autenticação SCRAM-SHA-256
├── ssl/
│   ├── certs/                  # Certificados SSL (públicos)
│   └── private/                # Chaves privadas (NÃO VERSIONAR)
├── init-scripts/               # Scripts de inicialização
├── backups/                    # Backups criptografados
├── logs/                       # Logs do PostgreSQL
├── generate-ssl-certs.sh       # Gerar certificados SSL
├── backup-postgres.sh          # Backup automatizado
└── README.md                   # Esta documentação
```

---

## 🚀 Instalação (Primeira Vez)

### 1. Configurar Variáveis de Ambiente

```bash
# Copiar template
cp .env.example .env

# Gerar senha forte
python -c "import secrets, string; chars = string.ascii_letters + string.digits + string.punctuation; print(''.join(secrets.choice(chars) for _ in range(32)))"

# Editar .env com as senhas geradas
nano .env
```

**Exemplo de `.env`:**
```env
DB_USER=postgres_admin_prod
DB_PASSWORD=Xk9#mP2$vL8@qR5&nF3*wT7!zC4^hB6
DB_NAME=bot_whatsapp_prod
DB_PORT=5432
BACKUP_PASSWORD=your_backup_encryption_password_here
```

### 2. Gerar Certificados SSL

```bash
# Executar script de geração
bash generate-ssl-certs.sh

# Verificar certificados criados
ls -lh ssl/certs/
ls -lh ssl/private/
```

### 3. Iniciar o Container

```bash
# Criar rede externa (se não existir)
docker network create rede-global

# Iniciar PostgreSQL
docker-compose up -d

# Verificar logs
docker-compose logs -f
```

### 4. Verificar Saúde do Container

```bash
# Status do container
docker ps | grep postgres-central

# Healthcheck
docker inspect postgres-central | grep -A 5 Health

# Conectar ao banco (teste)
docker exec -it postgres-central psql -U $DB_USER -d $DB_NAME
```

---

## 🔄 Migração do Banco Antigo

### Se você tem dados no banco antigo:

```bash
# 1. Fazer backup do banco antigo
docker exec postgres-antigo pg_dump -U admin -d bot_whatsapp > backup_antigo.sql

# 2. Iniciar novo container seguro
docker-compose up -d

# 3. Restaurar dados
cat backup_antigo.sql | docker exec -i postgres-central psql -U $DB_USER -d $DB_NAME

# 4. Verificar dados restaurados
docker exec -it postgres-central psql -U $DB_USER -d $DB_NAME -c "\dt"
```

---

## 🔒 Conectar Aplicações ao Banco Seguro

### Connection Strings:

**Python (SQLAlchemy):**
```python
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@localhost:5432/{DB_NAME}?sslmode=require"
```

**Node.js (pg):**
```javascript
const pool = new Pool({
    host: 'localhost',
    port: 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    ssl: {
        rejectUnauthorized: false,  // ou true com certificado CA
        ca: fs.readFileSync('./ssl/certs/ca.crt').toString(),
    }
});
```

**DBeaver / PgAdmin:**
- Host: `localhost`
- Port: `5432`
- Database: `bot_whatsapp_prod`
- Username: (valor de `DB_USER`)
- Password: (valor de `DB_PASSWORD`)
- SSL Mode: `require`

---

## 💾 Backups

### Backup Manual:

```bash
# Executar backup completo
bash backup-postgres.sh

# Backups ficam em: ./backups/
```

### Backup Automatizado (Cron):

```bash
# Editar crontab
crontab -e

# Adicionar linha (backup diário às 2h da manhã)
0 2 * * * cd /caminho/para/postgres-central && bash backup-postgres.sh >> logs/cron-backup.log 2>&1
```

### Restaurar Backup:

```bash
# Descompactar backup
gunzip backups/full_backup_YYYYMMDD_HHMMSS.sql.gz

# Descriptografar (se criptografado)
openssl enc -aes-256-cbc -d -pbkdf2 -in backup.sql.gz.enc -out backup.sql.gz -pass pass:$BACKUP_PASSWORD

# Restaurar
cat backups/full_backup_YYYYMMDD_HHMMSS.sql | docker exec -i postgres-central psql -U $DB_USER
```

---

## 🛡️ Segurança Implementada

✅ **Credenciais em Variáveis de Ambiente** (não hardcoded)
✅ **Porta Bind apenas Localhost** (não exposta publicamente)
✅ **Autenticação SCRAM-SHA-256** (mais forte que MD5)
✅ **SSL/TLS Habilitado** (tráfego criptografado)
✅ **Rede Interna Isolada** (sem acesso externo direto)
✅ **Backup Automatizado** (com criptografia)
✅ **Logs de Auditoria** (conexões, queries DDL)
✅ **Timeouts de Segurança** (previne ataques de DoS)
✅ **Healthcheck** (monitoramento de saúde)
✅ **Security Opts** (no-new-privileges, cap_drop)
✅ **Limites de Recursos** (CPU, memória)

---

## 📊 Monitoramento

### Ver Logs:

```bash
# Logs do container
docker-compose logs -f

# Logs do PostgreSQL
tail -f logs/postgresql-*.log
```

### Métricas:

```bash
# Conexões ativas
docker exec postgres-central psql -U $DB_USER -d $DB_NAME -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# Tamanho do banco
docker exec postgres-central psql -U $DB_USER -d $DB_NAME -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));"

# Queries lentas (> 1s)
docker exec postgres-central psql -U $DB_USER -d $DB_NAME -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements WHERE mean_time > 1000 ORDER BY mean_time DESC LIMIT 10;"
```

---

## 🔧 Manutenção

### Rotação de Senhas (a cada 90 dias):

```bash
# 1. Gerar nova senha
python -c "import secrets; print(secrets.token_urlsafe(32))"

# 2. Atualizar no banco
docker exec -it postgres-central psql -U $DB_USER -d postgres -c "ALTER USER $DB_USER WITH PASSWORD 'NOVA_SENHA';"

# 3. Atualizar .env
# DB_PASSWORD=NOVA_SENHA

# 4. Reiniciar aplicações que conectam ao banco
```

### Atualizar PostgreSQL:

```bash
# 1. Backup completo
bash backup-postgres.sh

# 2. Parar container
docker-compose down

# 3. Atualizar imagem no docker-compose.yml
# image: postgres:16-alpine  # versão mais nova

# 4. Iniciar com nova versão
docker-compose up -d
```

---

## ⚠️ Troubleshooting

### Problema: Container não inicia

```bash
# Ver logs de erro
docker-compose logs db

# Verificar permissões dos certificados SSL
ls -lh ssl/private/server.key  # deve ser 600
```

### Problema: Aplicação não conecta

```bash
# Verificar se porta está aberta
netstat -tlnp | grep 5432

# Testar conexão
psql "postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME?sslmode=require"
```

### Problema: Backup falha

```bash
# Verificar espaço em disco
df -h

# Verificar logs de backup
tail -f logs/backup_*.log
```

---

## 📚 Referências

- [PostgreSQL Security Best Practices](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)
- [Docker Security](https://docs.docker.com/engine/security/)
- [SCRAM-SHA-256 Authentication](https://www.postgresql.org/docs/current/sasl-authentication.html)

---

## 🆘 Suporte

Em caso de problemas:
1. Verificar logs: `docker-compose logs -f`
2. Verificar healthcheck: `docker inspect postgres-central`
3. Revisar este README
4. Consultar documentação oficial do PostgreSQL

---

**Criado:** 2025-01-24  
**Última atualização:** 2025-01-24
