#!/bin/bash
# Script de Backup Automatizado para PostgreSQL
# Uso: ./backup-postgres.sh [full|incremental]

set -euo pipefail

# --- CONFIGURAÇÕES ---
BACKUP_DIR="./backups"
LOGS_DIR="./logs"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_CONTAINER="postgres-central"

# Carregar variáveis de ambiente
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ Arquivo .env não encontrado!"
    exit 1
fi

# Criar diretórios
mkdir -p "$BACKUP_DIR" "$LOGS_DIR"

# Arquivo de log
LOG_FILE="$LOGS_DIR/backup_${TIMESTAMP}.log"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# --- BACKUP COMPLETO ---
backup_full() {
    log "🔄 Iniciando backup completo..."
    
    # Backup de todos os bancos (pg_dumpall)
    log "  - Fazendo pg_dumpall..."
    docker exec -t "$DB_CONTAINER" pg_dumpall -U "$DB_USER" | \
        gzip > "$BACKUP_DIR/full_backup_${TIMESTAMP}.sql.gz"
    
    # Backup individual do banco principal (formato custom para restore seletivo)
    log "  - Fazendo backup do banco $DB_NAME..."
    docker exec -t "$DB_CONTAINER" pg_dump -U "$DB_USER" -Fc "$DB_NAME" > \
        "$BACKUP_DIR/db_${DB_NAME}_${TIMESTAMP}.dump"
    
    log "✅ Backup completo finalizado"
}

# --- VERIFICAR INTEGRIDADE ---
verify_backup() {
    local backup_file=$1
    log "🔍 Verificando integridade do backup..."
    
    if file "$backup_file" | grep -q "gzip"; then
        if gzip -t "$backup_file" 2>/dev/null; then
            log "✅ Backup íntegro: $(basename $backup_file)"
            return 0
        else
            log "❌ Backup corrompido: $(basename $backup_file)"
            return 1
        fi
    else
        log "✅ Backup verificado: $(basename $backup_file)"
        return 0
    fi
}

# --- CRIPTOGRAFAR BACKUP ---
encrypt_backup() {
    local backup_file=$1
    
    if [ -z "$BACKUP_PASSWORD" ]; then
        log "⚠️  BACKUP_PASSWORD não configurada. Pulando criptografia."
        return 0
    fi
    
    log "🔒 Criptografando backup..."
    
    echo "$BACKUP_PASSWORD" | openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in "$backup_file" \
        -out "${backup_file}.enc" \
        -pass stdin
    
    if [ $? -eq 0 ]; then
        rm -f "$backup_file"  # Remover versão não criptografada
        log "✅ Backup criptografado: $(basename ${backup_file}.enc)"
        return 0
    else
        log "❌ Erro ao criptografar backup"
        return 1
    fi
}

# --- LIMPAR BACKUPS ANTIGOS ---
cleanup_old_backups() {
    log "🧹 Removendo backups com mais de ${RETENTION_DAYS} dias..."
    
    local deleted_count=0
    
    # Arquivos .gz
    deleted_count=$(find "$BACKUP_DIR" -name "*.gz" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
    [ $deleted_count -gt 0 ] && log "  - Removidos $deleted_count arquivos .gz"
    
    # Arquivos .enc
    deleted_count=$(find "$BACKUP_DIR" -name "*.enc" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
    [ $deleted_count -gt 0 ] && log "  - Removidos $deleted_count arquivos .enc"
    
    # Arquivos .dump
    deleted_count=$(find "$BACKUP_DIR" -name "*.dump" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
    [ $deleted_count -gt 0 ] && log "  - Removidos $deleted_count arquivos .dump"
    
    log "✅ Limpeza concluída"
}

# --- ESTATÍSTICAS ---
show_stats() {
    log "📊 Estatísticas de Backup:"
    log "  - Total de backups: $(ls -1 $BACKUP_DIR/*.{gz,enc,dump} 2>/dev/null | wc -l)"
    log "  - Espaço usado: $(du -sh $BACKUP_DIR | cut -f1)"
    log "  - Backup mais antigo: $(ls -t $BACKUP_DIR | tail -1 || echo 'nenhum')"
}

# --- NOTIFICAÇÃO (opcional) ---
notify() {
    local status=$1
    local message=$2
    
    # Implementar notificação via webhook, email, etc
    # Exemplo: curl -X POST https://hooks.slack.com/... -d "{\"text\":\"$message\"}"
    log "📢 $message"
}

# --- MAIN ---
main() {
    log "========================================="
    log "  BACKUP POSTGRESQL - Início"
    log "========================================="
    
    # Verificar se container está rodando
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log "❌ Container $DB_CONTAINER não está rodando!"
        notify "error" "Backup falhou: container não está rodando"
        exit 1
    fi
    
    # Executar backup
    backup_full
    
    # Verificar último backup criado
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/full_backup_*.sql.gz 2>/dev/null | head -1)
    
    if [ -n "$LATEST_BACKUP" ]; then
        if verify_backup "$LATEST_BACKUP"; then
            encrypt_backup "$LATEST_BACKUP"
            
            # Upload para storage remoto (opcional - descomentar se usar)
            # upload_to_s3 "${LATEST_BACKUP}.enc"
            
            log "✅ Backup concluído com sucesso!"
            notify "success" "Backup PostgreSQL concluído: $(basename $LATEST_BACKUP)"
        else
            log "❌ Backup falhou na verificação!"
            notify "error" "Backup PostgreSQL falhou na verificação"
            exit 1
        fi
    else
        log "❌ Nenhum backup foi criado!"
        notify "error" "Backup PostgreSQL não foi criado"
        exit 1
    fi
    
    # Limpar backups antigos
    cleanup_old_backups
    
    # Mostrar estatísticas
    show_stats
    
    log "========================================="
    log "  BACKUP POSTGRESQL - Concluído"
    log "========================================="
}

# Executar
main "$@"
