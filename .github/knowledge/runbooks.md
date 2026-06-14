# Runbooks — Suporte N2 Farmácia Boa Vista

> **Audiência:** Time Suporte N2  
> **Atualizado em:** 2026-06-14  
> **Contatos de escalonamento:** [.github/knowledge/contacts.md](contacts.md)

---

## Índice

1. [RB-01 — Restart do serviço de PDV no Azure App Service](#rb-01--restart-do-serviço-de-pdv-no-azure-app-service)
2. [RB-02 — Rollback de deploy via GitHub Actions](#rb-02--rollback-de-deploy-via-github-actions)
3. [RB-03 — Investigação de falha no Azure SQL (queries lentas / locks)](#rb-03--investigação-de-falha-no-azure-sql-queries-lentas--locks)

---

## RB-01 — Restart do serviço de PDV no Azure App Service

### Objetivo

Reiniciar a instância do App Service `bvista-pdv-api` para recuperação de erros de processo,
memory leak ou estado inconsistente sem necessidade de novo deploy.

### Pré-requisitos

- Acesso ao Azure Portal com role **Contributor** ou superior no resource group `rg-bvista-prod`
- CLI: `az` instalado e autenticado (`az login`) **ou** acesso ao Azure Portal via browser
- Confirmar com o Tech Lead que o restart foi autorizado (incidentes P1/P2)

### Passos

1. **Confirme o estado atual do serviço:**
   ```bash
   az webapp show \
     --name bvista-pdv-api \
     --resource-group rg-bvista-prod \
     --query "state" -o tsv
   ```
   Esperado: `Running`. Se `Stopped`, vá direto ao passo 4.

2. **Verifique os logs recentes antes do restart** para registrar a causa:
   ```bash
   az webapp log tail \
     --name bvista-pdv-api \
     --resource-group rg-bvista-prod \
     --provider application
   ```
   Copie as últimas 50 linhas para o comentário da GitHub Issue do incidente.

3. **Execute o restart:**
   ```bash
   az webapp restart \
     --name bvista-pdv-api \
     --resource-group rg-bvista-prod
   ```
   Via portal: App Service → `bvista-pdv-api` → Overview → **Restart**.

4. **Se o serviço estava parado, inicie-o:**
   ```bash
   az webapp start \
     --name bvista-pdv-api \
     --resource-group rg-bvista-prod
   ```

5. **Aguarde 60 segundos** e verifique o health check:
   ```bash
   curl -sf https://bvista-pdv-api.azurewebsites.net/health | jq .
   ```

6. **Registre o restart** no comentário da GitHub Issue com timestamp e resultado.

### Verificação de sucesso

- `az webapp show ... --query "state"` retorna `Running`
- Health check retorna HTTP 200 com `{"status": "healthy"}`
- Sem erros 5xx nos logs nos 5 minutos seguintes ao restart

### Contato em caso de falha

Se o serviço não subir após 2 tentativas → escalar para **Tech Lead N2**.  
Consulte a matriz de escalonamento: [contacts.md](contacts.md)

---

## RB-02 — Rollback de deploy via GitHub Actions

### Objetivo

Reverter a versão em produção para o último artefato estável quando um deploy causa
regressão crítica ou instabilidade.

### Pré-requisitos

- Acesso de **write** ao repositório `bvista-dev/pdv-api` no GitHub
- Identificar o SHA ou tag do último commit estável (verificar histórico de deploy no Actions)
- Aprovação do Tech Lead antes de iniciar (rollback afeta todos os usuários em produção)

### Passos

1. **Identifique o último workflow de deploy bem-sucedido:**
   - GitHub → Actions → workflow `Deploy to Production`
   - Anote o **Run ID** e o **SHA do commit** do último run com status `success` antes do incidente

2. **Crie uma branch de rollback a partir do SHA estável:**
   ```bash
   git fetch origin
   git checkout -b rollback/<data>-<sha-curto> <SHA_ESTAVEL>
   git push -u origin rollback/<data>-<sha-curto>
   ```

3. **Acione o workflow de deploy apontando para essa branch:**
   - GitHub → Actions → `Deploy to Production` → **Run workflow**
   - Selecione a branch `rollback/<data>-<sha-curto>`
   - Clique em **Run workflow**

   Alternativa via CLI:
   ```bash
   gh workflow run deploy-prod.yml \
     --ref rollback/<data>-<sha-curto> \
     --repo edymonte/bvista-workshop
   ```

4. **Acompanhe o pipeline** em tempo real:
   ```bash
   gh run watch --repo edymonte/bvista-workshop
   ```

5. **Após o deploy concluir**, execute o health check:
   ```bash
   curl -sf https://bvista-pdv-api.azurewebsites.net/health | jq .
   ```

6. **Registre o rollback** no comentário da GitHub Issue:
   - SHA revertido → SHA estável
   - Timestamp de início e fim
   - Motivo do rollback

7. **Abra uma issue de investigação** com label `bug` + `needs-root-cause` para análise pós-incidente.

### Verificação de sucesso

- Pipeline `Deploy to Production` finaliza com status `success`
- Health check retorna HTTP 200 com `{"status": "healthy"}`
- Versão retornada pelo endpoint `/version` corresponde ao SHA estável esperado:
  ```bash
  curl -sf https://bvista-pdv-api.azurewebsites.net/version | jq .commit
  ```

### Contato em caso de falha

Pipeline falhou ou saúde não restaurada após rollback → escalar para **Tech Lead + Dev Squad Lead**.  
Consulte: [contacts.md](contacts.md)

---

## RB-03 — Investigação de falha no Azure SQL (queries lentas / locks)

### Objetivo

Diagnosticar degradação de performance ou bloqueios (locks) no banco Azure SQL
`bvista-pdv-db` que estejam causando timeouts ou lentidão na API.

### Pré-requisitos

- Acesso ao Azure Portal com role **Reader** no SQL Server `bvista-sql-prod` **ou**
  credenciais de leitura no banco (usuário `n2_readonly`) — obtidas via Azure Key Vault
- Ferramenta: Azure Data Studio **ou** `sqlcmd` instalado
- **Nunca** executar comandos de escrita (`UPDATE`, `DELETE`, `KILL`) sem aprovação explícita do DBA

### Passos

#### 1. Identifique queries ativas e seus tempos de execução

```sql
SELECT
    r.session_id,
    r.status,
    r.wait_type,
    r.wait_time / 1000.0          AS wait_seconds,
    r.total_elapsed_time / 1000.0 AS elapsed_seconds,
    r.cpu_time / 1000.0           AS cpu_seconds,
    r.logical_reads,
    SUBSTRING(st.text, (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
          ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1
    )                             AS query_text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id <> @@SPID
ORDER BY r.total_elapsed_time DESC;
```

#### 2. Identifique locks e sessões bloqueadas

```sql
SELECT
    blocking.session_id  AS blocker_session_id,
    blocked.session_id   AS blocked_session_id,
    blocked.wait_type,
    blocked.wait_time / 1000.0 AS wait_seconds,
    SUBSTRING(bt.text, 1, 200)  AS blocker_query,
    SUBSTRING(dt.text, 1, 200)  AS blocked_query
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_requests blocking
    ON blocked.blocking_session_id = blocking.session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle)  dt
CROSS APPLY sys.dm_exec_sql_text(blocking.sql_handle) bt
WHERE blocked.blocking_session_id > 0;
```

#### 3. Verifique queries mais custosas no Query Store

```sql
SELECT TOP 10
    qt.query_sql_text,
    rs.avg_duration / 1000.0     AS avg_ms,
    rs.avg_logical_io_reads,
    rs.count_executions,
    rs.last_execution_time
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q      ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan p       ON q.query_id       = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id    = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
ORDER BY rs.avg_duration DESC;
```

#### 4. Verifique índices ausentes recomendados pelo SQL

```sql
SELECT TOP 10
    d.statement                        AS table_name,
    d.equality_columns,
    d.inequality_columns,
    d.included_columns,
    s.avg_total_user_cost * s.avg_user_impact * (s.user_seeks + s.user_scans)
                                       AS improvement_score,
    s.last_user_seek
FROM sys.dm_db_missing_index_details d
JOIN sys.dm_db_missing_index_groups g  ON d.index_handle = g.index_handle
JOIN sys.dm_db_missing_index_group_stats s ON g.index_group_handle = s.group_handle
ORDER BY improvement_score DESC;
```

#### 5. Documente e escale se necessário

- Copie os resultados das queries acima para o comentário da GitHub Issue
- Se houver sessão bloqueada há mais de **5 minutos**: notifique o **DBA** e o **Tech Lead**
- Se o DBA autorizar: executar `KILL <session_id>` apenas para a sessão bloqueante confirmada
- **Nunca** criar índices em produção sem janela de manutenção aprovada

### Verificação de sucesso

- Nenhuma sessão com `wait_time` > 30 segundos em `sys.dm_exec_requests`
- Latência média da API (`/health` ou APM) retorna ao baseline (< 500 ms p95)
- Sem erros de timeout nos logs do App Service nos 5 minutos seguintes

### Contato em caso de falha

Locks persistentes ou degradação não resolvida → escalar para **DBA** + **Tech Lead**.  
Consulte: [contacts.md](contacts.md)
