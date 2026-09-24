# Español

## Operaciones

Todos los recursos están diseñados para AWS, pero no se han desplegado en AWS.
Las aplicaciones de prueba solo exponen / y /healthz. No hay aplicación de negocio,
pipeline de datos, autenticación real de usuarios, autoescalado ni DR avanzado.

Los cambios usan ramas de funcionalidad hacia develop; la promoción a main se
realiza por PR. Nunca hagas push directo a main. CI valida ambas configuraciones;
la integración local es independiente. Las comprobaciones reales de drift AWS
usan una identidad temporal dedicada o el workflow manual habilitado, no
credenciales locales descubiertas en una estación de trabajo.

Inspecciona streams CloudWatch de aplicación/inicialización y logs ALB en S3
para diagnosticar fallos. Los secretos nunca deben estar en user data ni logs.
La entrega de CloudWatch Agent, comportamiento NACL, emisión TLS y conmutación
por fallo deben probarse en un entorno AWS autorizado.

Reemplaza EC2 fijas no saludables mediante un plan Terraform revisado. No existe
controlador de reemplazo automático. Backoffice sigue inaccesible hasta proporcionar
CIDR de operadores. Crea usuarios restringidos de base de datos y carga los tres
secretos de aplicación antes del lanzamiento; los roles EC2 no pueden leer secretos
maestros RDS. Los clientes Redis deben renovar tokens IAM.

La eliminación de datos PROD está protegida. Una retirada intencional requiere
revisar por separado el cambio de protección y usar identificadores únicos de
snapshots finales; cambia el identificador predeterminado si ya existe un snapshot
con ese nombre. Conserva copias y verifica restauraciones antes de destruir datos
persistentes. El almacenamiento de estado del bootstrap es independiente y no
debe eliminarse junto con la aplicación.

---

# English

## Operations

All resources are currently AWS-compatible by design but undeployed to AWS.
Smoke applications expose / and /healthz only. There is no business application,
data pipeline, real user authentication, autoscaling or advanced DR.

Routine changes use feature branches into develop; promote by PR to main. Never
push directly to main. Required CI validates both shapes; local integration is
separate. Real AWS drift checks use an dedicated temporary identity or enabled
manual workflow, not local credentials discovered on a workstation.

Inspect application/bootstrap CloudWatch streams and ALB S3 logs for failures.
Secrets never belong in user data or logs. Agent delivery, network ACL behavior,
TLS issuance and failover must be tested in an authorized AWS environment.

Replace unhealthy fixed EC2 instances through a reviewed Terraform plan. There
is no automatic replacement controller. Backoffice remains unreachable until
operator CIDRs are supplied. Create restricted database users and populate the
three application secrets before production launch; EC2 roles cannot read RDS
master secrets. Redis clients must implement IAM token refresh.

PROD data deletion is protected. Intentional teardown requires a separately
reviewed protection change and unique final snapshot identifiers; the default
final identifier must be changed if a previous snapshot already uses it.
Retain backups and verify restores before destroying persistent resources.
Bootstrap state storage is independent and must not be torn down with the app.
