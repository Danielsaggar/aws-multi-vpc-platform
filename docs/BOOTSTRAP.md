# Español

## Bootstrap y migración de estado

El bootstrap requiere una identidad administrativa temporal dedicada en la cuenta
de destino. No almacenes credenciales en el repositorio ni en la configuración del backend.

Ejecuta el bootstrap por separado en las cuentas DEV y PROD. Proporciona account_id,
environment, github_repository exacto, hosted_zone_id y, opcionalmente, el ARN de
un proveedor OIDC existente. Terraform comienza con estado local. Protege la carpeta
de trabajo: el estado es sensible aunque las credenciales sean administradas por el servicio.

Comprobaciones sin acceso a AWS:

```sh
terraform -chdir=bootstrap init -backend=false
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap test
```

Usa una identidad administrativa temporal dedicada, verifica la cuenta de destino
y planifica, revisa y aplica el bootstrap. Crea el bucket cifrado y versionado,
la clave KMS, el proveedor OIDC, los roles de plan/despliegue y el límite de permisos
de las cargas. `prevent_destroy` protege el bucket de estado y la clave. Los roles
de despliegue de plataforma no pueden cambiar el estado del bootstrap ni su propia confianza OIDC.

Migración tras completar el bootstrap:

1. Respalda el estado local en una ubicación cifrada con acceso controlado.
2. Copia backend.tf.example a backend.tf (ignorado).
3. Prepara un backend.hcl privado con el bucket de salida, región ca-central-1,
   clave `bootstrap/ENV/terraform.tfstate`, encrypt=true, use_lockfile=true y el
   ARN KMS en kms_key_id. Usa bootstrap/backend.hcl.example como plantilla y cambia
   dev por prod para PROD. No incluyas credenciales en la configuración del backend.
4. Ejecuta `terraform -chdir=bootstrap init -migrate-state -backend-config=backend.hcl`.
5. Verifica objeto/versión remotos, lista de estado y un plan sin cambios usando
   la misma identidad. Prueba la contención de bloqueo con dos operaciones administrativas concurrentes.
6. Elimina copias locales redundantes solo después de verificar la recuperación;
   conserva el respaldo protegido según la política de la organización.

El estado de plataforma usa `platform/ENV/terraform.tfstate`. Los roles pueden
leer/escribir su objeto de bloqueo; solo deploy puede escribir el estado de
plataforma. Restaura versiones anteriores únicamente con acceso exclusivo,
incidente registrado y un plan nuevo. Nunca fuerces el desbloqueo de una operación
activa. Renueva credenciales mediante OIDC, no mediante claves de acceso almacenadas.

La política del bucket rechaza escrituras sin SSE-KMS explícito o sin el ARN exacto
de la clave del bootstrap, tanto para estado como para locks. El cifrado predeterminado
no sustituye esos encabezados; kms_key_id los configura en el backend. Se mantiene
el rechazo de transporte sin TLS. No se ha demostrado su cumplimiento en AWS real.
Consulta [SSE-KMS en S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html).

Las pruebas simuladas no demuestran bloqueo condicional S3 ni federación OIDC real.
Consulta la [guía del backend de HashiCorp](https://developer.hashicorp.com/terraform/language/backend/s3).

---

# English

## Bootstrap and state migration

Bootstrap requires a dedicated temporary administrative identity in the target
account. Do not store credentials in the repository or backend configuration.

Run bootstrap separately in the DEV and PROD accounts. Supply account_id,
environment, exact github_repository, hosted_zone_id and optionally an existing
OIDC provider ARN. Terraform starts with local state. Protect the working folder;
state is sensitive even though credentials are service-managed.

Checks without AWS access:

```sh
terraform -chdir=bootstrap init -backend=false
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap test
```

Use a dedicated temporary administrative identity,
verify the intended account, then plan/review/apply bootstrap. It creates the
encrypted versioned bucket, KMS key, OIDC provider, plan/deploy roles and workload
boundary. `prevent_destroy` guards state bucket/key. Platform deployment roles cannot
change bootstrap state or their own OIDC trust.

Migration after successful bootstrap:

1. Back up local state to an access-controlled encrypted location.
2. Copy backend.tf.example to backend.tf (ignored).
3. Prepare a private backend.hcl with bucket output, region ca-central-1,
   key `bootstrap/ENV/terraform.tfstate`, encrypt=true, use_lockfile=true and
   the KMS key ARN in kms_key_id. Use bootstrap/backend.hcl.example as the template
   and change dev to prod for PROD. Do not put credentials in backend configuration.
4. Run `terraform -chdir=bootstrap init -migrate-state -backend-config=backend.hcl`.
5. Verify remote object/version, state list, and a no-change plan under the same
   identity. Exercise lock contention using two concurrent administrative operations.
6. Remove redundant local state copies only after recovery is verified; retain
   the protected backup according to organizational policy.

Platform state uses `platform/ENV/terraform.tfstate`. Roles can read/write its
lock object; only deploy can write platform state. Restore prior versions only
with exclusive access, a recorded incident and a fresh plan. Never force-unlock
an active operation. Rotate credentials through OIDC, not stored access keys.

The bucket policy rejects writes without explicit SSE-KMS or the exact bootstrap
key ARN, for both state and locks. Default encryption does not replace those
headers; kms_key_id configures them in the backend. Non-TLS transport remains
denied. Enforcement has not been demonstrated on real AWS.
See [S3 SSE-KMS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html).

Mock tests do not prove S3 conditional locking or actual OIDC federation.
See [HashiCorp backend guidance](https://developer.hashicorp.com/terraform/language/backend/s3).
