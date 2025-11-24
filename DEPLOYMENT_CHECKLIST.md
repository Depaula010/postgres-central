# ✅ Checklist de Deployment - PostgreSQL Seguro

## 📋 Antes de Fazer Deploy

### 1. Configuração Básica

- [ ] Arquivo `.env` criado (copiado de `.env.example`)
- [ ] Senha forte configurada (32+ caracteres)
- [ ] `.gitignore` está correto (`.env` não será versionado)
- [ ] Certificados SSL gerados (`bash generate-ssl-certs.sh`)

### 2. Docker

- [ ] Docker e Docker Compose instalados
- [ ] Rede Docker criada (`docker network create rede-global`)
- [ ] Porta 5432 está livre (`netstat -an | findstr 5432`)
- [ ] Espaço em disco suficiente (>10GB para dados + backups)

### 3. Segurança

- [ ] Porta bind apenas localhost (`127.0.0.1:5432:5432`)
- [ ] Autenticação SCRAM-SHA-256 configurada
- [ ] SSL habilitado (certificados válidos)
- [ ] `pg_hba.conf` revisado (apenas IPs necessários)
- [ ] Security opts aplicados (no-new-privileges)

### 4. Backup

- [ ] Script de backup testado (`bash backup-postgres.sh`)
- [ ] Senha de criptografia configurada (`BACKUP_PASSWORD`)
- [ ] Cron job ou systemd timer configurado (backup diário)
- [ ] Teste de restore realizado

---

## 🚀 Deploy (Primeira Vez)

### Passo 1: Preparar Ambiente

```bash
cd e:\Projetos\Projetos\postgres-central

# Configurar secrets
cp .env.example .env
nano .env  # Editar com senhas fortes

# Gerar certificados SSL
bash generate-ssl-certs.sh
```

### Passo 2: Iniciar Container

```bash
# Criar rede (se não existir)
docker network create rede-global

# Iniciar PostgreSQL
docker-compose up -d

# Verificar logs
docker-compose logs -f db
```

### Passo 3: Verificar Saúde

```bash
# Status do container
docker ps | grep postgres-central

# Healthcheck
docker inspect postgres-central | grep -A 5 Health

# Conectar e testar
docker exec -it postgres-central psql -U $DB_USER -d $DB_NAME -c "SELECT version();"
```

### Passo 4: Migrar Dados (se aplicável)

```bash
# Backup do banco antigo
docker exec postgres-antigo pg_dump -U admin bot_whatsapp > backup_antigo.sql

# Restaurar no novo banco
cat backup_antigo.sql | docker exec -i postgres-central psql -U $DB_USER -d $DB_NAME

# Verificar dados
docker exec -it postgres-central psql -U $DB_USER -d $DB_NAME -c "\dt"
```

### Passo 5: Atualizar Aplicações

**Backend Python (`AppControleFinanceiro/.env`):**
```env
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}
```

**Bot WhatsApp (`bot-appfinanceiro-whatsapp/.env`):**
```env
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@postgres-central:5432/${DB_NAME}
```

### Passo 6: Configurar Backup Automático

```bash
# Testar backup manual
bash backup-postgres.sh

# Adicionar ao cron (Linux/Mac)
crontab -e
# Adicionar: 0 2 * * * cd /path/to/postgres-central && bash backup-postgres.sh >> logs/cron-backup.log 2>&1

# Ou usar Task Scheduler (Windows)
# - Trigger: Daily, 2:00 AM
# - Action: Run bash backup-postgres.sh
```

---

## 🔄 Deploy (Atualizações)

### Atualizar Configurações

```bash
# Editar configurações
nano config/postgresql.conf

# Recarregar (sem downtime)
docker exec postgres-central psql -U $DB_USER -c "SELECT pg_reload_conf();"

# Ou reiniciar container
docker-compose restart db
```

### Atualizar Versão do PostgreSQL

```bash
# 1. BACKUP COMPLETO
bash backup-postgres.sh

# 2. Parar container
docker-compose down

# 3. Editar docker-compose.yml
# image: postgres:16-alpine  # versão mais nova

# 4. Iniciar com nova versão
docker-compose up -d

# 5. Verificar logs
docker-compose logs -f db
```

---

## 🔐 Rotação de Senhas

### A cada 90 dias:

```bash
# 1. Gerar nova senha
NEW_PASSWORD=$(python -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits + '!@#$%^&*') for _ in range(32)))")
echo "Nova senha: $NEW_PASSWORD"

# 2. Atualizar no banco
docker exec -it postgres-central psql -U $DB_USER -d postgres -c "ALTER USER $DB_USER WITH PASSWORD '$NEW_PASSWORD';"

# 3. Atualizar .env do banco
nano .env  # DB_PASSWORD=NOVA_SENHA

# 4. Atualizar .env das aplicações
nano ../AppControleFinanceiro/.env
nano ../bot-appfinanceiro-whatsapp/.env

# 5. Reiniciar aplicações
docker-compose -f ../AppControleFinanceiro/docker-compose.yml restart
docker-compose -f ../bot-appfinanceiro-whatsapp/docker.composer.yml restart
```

---

## 🧪 Testes de Segurança

### Verificar Configuração

```bash
# 1. Porta não está exposta publicamente
nmap -p 5432 SEU_IP_PUBLICO  # Deve retornar "filtered" ou "closed"

# 2. SSL está ativo
docker exec postgres-central psql -U $DB_USER -d $DB_NAME -c "SHOW ssl;"
# Deve retornar: on

# 3. Autenticação é SCRAM
docker exec postgres-central psql -U $DB_USER -d $DB_NAME -c "SHOW password_encryption;"
# Deve retornar: scram-sha-256

# 4. Logs estão funcionando
docker exec postgres-central tail /var/log/postgresql/postgresql-*.log

# 5. Backup está funcionando
ls -lh backups/
```

### Testar Restore

```bash
# 1. Fazer backup de teste
bash backup-postgres.sh

# 2. Criar banco temporário para teste
docker exec -it postgres-central psql -U $DB_USER -d postgres -c "CREATE DATABASE test_restore;"

# 3. Restaurar backup
LATEST_BACKUP=$(ls -t backups/full_backup_*.sql.gz | head -1)
gunzip -c "$LATEST_BACKUP" | docker exec -i postgres-central psql -U $DB_USER -d test_restore

# 4. Verificar dados
docker exec -it postgres-central psql -U $DB_USER -d test_restore -c "\dt"

# 5. Remover banco de teste
docker exec -it postgres-central psql -U $DB_USER -d postgres -c "DROP DATABASE test_restore;"
```

---

## 📊 Monitoramento (Pós-Deploy)

### Diário

- [ ] Verificar logs de erro: `docker-compose logs db | grep ERROR`
- [ ] Verificar espaço em disco: `df -h`
- [ ] Verificar último backup: `ls -lh backups/ | tail -1`

### Semanal

- [ ] Revisar logs de auditoria: `docker exec postgres-central cat /var/log/postgresql/postgresql-*.log | grep FATAL`
- [ ] Verificar conexões ativas: `docker exec postgres-central psql -U $DB_USER -d $DB_NAME -c "SELECT count(*) FROM pg_stat_activity;"`
- [ ] Testar restore de backup

### Mensal

- [ ] Rotação de senhas (se aplicável)
- [ ] Atualizar certificados SSL (se vencendo)
- [ ] Revisar `pg_hba.conf` (remover IPs antigos)
- [ ] Limpar logs antigos (>90 dias)

---

## 🆘 Rollback (Se algo der errado)

### Voltar para Configuração Antiga

```bash
# 1. Parar container novo
docker-compose down

# 2. Iniciar container antigo
docker start postgres-antigo  # ou seu container anterior

# 3. Atualizar connection strings das aplicações
# (reverter para configuração antiga)

# 4. Reiniciar aplicações
```

---

## 📞 Suporte

**Problemas comuns:**

1. **Container não inicia**: Verificar logs (`docker-compose logs db`)
2. **Aplicação não conecta**: Verificar senha no `.env` de cada aplicação
3. **Backup falha**: Verificar espaço em disco e permissões
4. **SSL não funciona**: Verificar permissões dos certificados (600 para `.key`)

---

✅ **Checklist Completo!** Você está pronto para deploy seguro!
