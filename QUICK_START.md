# ⚡ Quick Start - PostgreSQL Seguro

## 🚀 Em 5 Minutos

### 1. Configurar Secrets

```bash
cd e:\Projetos\Projetos\postgres-central

# Copiar template
cp .env.example .env

# Gerar senhas fortes
python -c "import secrets, string; print('DB_PASSWORD=' + ''.join(secrets.choice(string.ascii_letters + string.digits + '!@#$%^&*') for _ in range(32)))"

# Editar .env com a senha gerada
notepad .env
```

### 2. Gerar Certificados SSL

```bash
bash generate-ssl-certs.sh
```

Se estiver no Windows e não tiver bash, pule esta etapa por enquanto. O container funcionará sem SSL (menos seguro).

### 3. Iniciar Container

```bash
# Criar rede Docker (se não existir)
docker network create rede-global

# Iniciar PostgreSQL
docker-compose up -d

# Ver logs
docker-compose logs -f
```

### 4. Verificar

```bash
# Status
docker ps | grep postgres-central

# Testar conexão
docker exec -it postgres-central psql -U postgres_admin_prod -d bot_whatsapp_prod
```

---

## 📝 Atualizar Aplicações

### Backend Python:

Atualizar `DATABASE_URL` no `.env`:
```env
DATABASE_URL=postgresql://postgres_admin_prod:SUA_SENHA_AQUI@localhost:5432/bot_whatsapp_prod
```

### Bot WhatsApp:

Atualizar `DATABASE_URL` no `.env`:
```env
DATABASE_URL=postgresql://postgres_admin_prod:SUA_SENHA_AQUI@postgres-central:5432/bot_whatsapp_prod
```

---

## ⚠️ IMPORTANTE

1. **NUNCA** commite o arquivo `.env`
2. Use a **mesma senha** em todas as aplicações que conectam ao banco
3. Guarde a senha em um local seguro (gerenciador de senhas)

---

## 🆘 Problemas?

**Container não inicia:**
```bash
docker-compose logs db
```

**Aplicação não conecta:**
- Verifique se a senha no `.env` da aplicação está igual ao `.env` do banco
- Verifique se a porta 5432 está livre: `netstat -an | findstr 5432`

**Restaurar banco antigo:**
```bash
# Backup do banco antigo
docker exec postgres-antigo pg_dump -U admin bot_whatsapp > backup.sql

# Restaurar no novo banco
cat backup.sql | docker exec -i postgres-central psql -U postgres_admin_prod -d bot_whatsapp_prod
```

---

✅ **Pronto!** Seu PostgreSQL agora está 10x mais seguro!
