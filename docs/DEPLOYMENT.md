# Español

## Despliegue AWS (deshabilitado)

No se ha realizado ningún despliegue en AWS real. El despliegue AWS es manual y
está deshabilitado por defecto; configura los controles antes de habilitarlo.

Usa cuentas DEV/PROD separadas y un repositorio privado de despliegue con acceso
de lectura muy limitado: los planes Terraform pueden contener valores sensibles.
Un repositorio público de referencia o un zip sigue siendo una entrega válida del desafío.

Configura los entornos GitHub DEV y PROD con restricciones de ramas develop/main,
respectivamente. Exige revisores e impide la autorrevisión en PROD. Revisa el plan
guardado antes de aprobar el job apply. Habilita protección de ramas y comprobaciones
CI obligatorias. Los archivos de workflow no crean las protecciones de GitHub.

Cada entorno necesita las variables AWS_ACCOUNT_ID, AWS_PLAN_ROLE_ARN,
AWS_DEPLOY_ROLE_ARN, TF_BACKEND_HCL y TF_DEPLOYMENT_INPUTS_JSON. Esta última es
un objeto JSON de entradas Terraform no secretas de deployment.tfvars.example.
Establece AWS_DEPLOY_ENABLED=true solo después de revisar la preparación;
ausente/false omite el despliegue. No se usan secretos GitHub AWS_ACCESS_KEY_ID
ni AWS_SECRET_ACCESS_KEY.

El workflow valida entorno/rama/cuenta/privacidad del repositorio antes de OIDC,
planifica con el rol limitado, guarda el plan durante un día, verifica su hash y
commit y aplica ese mismo plan con el rol de despliegue. La concurrencia serializa
las operaciones del entorno. Los planes obsoletos fallan y deben regenerarse.
La protección de entornos GitHub es necesaria para la revisión del plan.

Antes de habilitarlo: confirma CIDR e identificadores AZ, revisa AMI/versiones de
motores y costos, verifica propiedad DNS, configura CIDR de operadores, revisa
alcances IAM, reemplaza aplicaciones de demostración, crea usuarios de base de
datos con mínimo privilegio y ejecuta pruebas AWS autorizadas de TLS, red,
conmutación por fallo, entrega de logs y restauración. Las acciones IAM pueden
requerir ajustes por SCP de la organización; esto no se ha probado en AWS.

Los sujetos OIDC son `repo:OWNER/REPO:environment:DEV` o `:PROD`, no sujetos de
rama. La correspondencia de ramas se exige mediante protección GitHub y el script
de control de despliegue.

---

# English

## AWS delivery (disabled)

No real AWS deployment has occurred. AWS delivery is manual-only and disabled
by default; configure the deployment controls before enabling it.

Use separate DEV/PROD accounts and a private deployment repository with tightly
limited read access: Terraform plans may contain sensitive values. A public
reference repository or zip remains a valid challenge deliverable.

Configure GitHub environments DEV and PROD with deployment branch restrictions
develop/main respectively. Require reviewers and prevent self-review for PROD.
Review the saved plan before approving the apply job. Enable appropriate branch
protection/required CI checks. Workflow files do not create GitHub protections.

Each environment needs variables AWS_ACCOUNT_ID, AWS_PLAN_ROLE_ARN,
AWS_DEPLOY_ROLE_ARN, TF_BACKEND_HCL and TF_DEPLOYMENT_INPUTS_JSON. The latter is a
JSON object of non-secret Terraform inputs from deployment.tfvars.example. Set
AWS_DEPLOY_ENABLED=true only after readiness review; absent/false skips delivery.
No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY GitHub secrets are used.

The workflow validates environment/branch/account/repository privacy before OIDC,
plans using the limited role, stores a one-day plan artifact, verifies its hash
and commit, then applies that exact plan using the deployment role. Concurrency
serializes the environment. Stale saved plans fail and must be regenerated.
GitHub environment protection is required for the plan-review boundary.

Before enabling: confirm CIDRs and AZ IDs, approve AMI/engine versions and costs,
verify DNS ownership, configure operator CIDRs, review IAM policy scopes, replace
demo applications, create least-privilege database users, and execute authorized
AWS TLS, network, failover, log-delivery and restore checks. IAM actions may need
adjustment for organization SCPs; this has not been exercised against AWS.

OIDC subjects are `repo:OWNER/REPO:environment:DEV` or `:PROD`, not branch subjects.
The branch mapping is enforced by GitHub protection plus the gate script.
