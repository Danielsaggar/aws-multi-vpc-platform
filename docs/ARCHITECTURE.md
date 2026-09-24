# Español

## Arquitectura

Consulta el [diagrama](diagrams/architecture.svg) y su [fuente Mermaid](diagrams/architecture.mmd).
Las cargas regionales usan `ca-central-1`; CloudFront e IAM son servicios globales.
Cuentas separadas alojan DEV (`develop`) y PROD (`main`). No se ha desplegado en AWS real.

### Diseño de red

| Entorno | VPC principal | VPC histórica |
| --- | --- | --- |
| DEV | 10.10.0.0/16 | 10.11.0.0/16 |
| PROD | 10.20.0.0/16 | 10.21.0.0/16 |

Dentro de cada /16 principal, las subredes /24 usan los siguientes valores del
tercer octeto: 0/1 para ALB/NAT públicos, 10/11 para aplicaciones, 20/21 para RDS
transaccional, 30/31 para Redis y 40/41 para endpoints de interfaz. Las VPC
históricas usan 20/21 para RDS. Dos identificadores de AZ explícitos son entradas;
valida su disponibilidad y la compatibilidad de CIDR en cada cuenta.

Las subredes públicas enrutan al Internet Gateway. Las aplicaciones usan NAT
gateways en su misma AZ en PROD y un NAT compartido en DEV. Los niveles de datos
y caché no tienen ruta predeterminada a Internet. Las rutas recíprocas de peering
conectan solo los CIDR de aplicaciones e históricos. El peering no ofrece acceso
transitivo a NAT ni al gateway de S3.

### Aplicaciones y datos

Las cuatro cargas son frontsite, backoffice, webapi y gameapi. DEV tiene una EC2
por carga (cuatro en total, distribuidas entre dos AZ); PROD tiene dos por carga
(ocho en total, una réplica por AZ). Las réplicas fijas proporcionan redundancia
sin Auto Scaling ni reemplazo automático de instancias. DEV acepta puntos únicos
de fallo en aplicaciones/NAT. La referencia de costos de cuatro EC2 del desafío
no equivale a disponibilidad multi-AZ por aplicación en PROD.

ALB enruta por host mediante HTTPS hacia EC2 en 8080; el puerto 80 redirige a 443.
Las solicitudes sin coincidencia reciben 403. Backoffice requiere además CIDR
de operadores; una lista vacía no crea regla de reenvío. EC2 no tiene IP pública
ni SSH, exige IMDSv2 y EBS cifrado. Los Security Groups aíslan las aplicaciones;
las NACL por nivel incluyen tráfico de solicitud y retorno efímero. Webapi/gameapi
acceden a RDS transaccional (5432) y Redis (6379); backoffice a RDS histórico (5432).
Frontsite no tiene acceso a bases de datos.

PostgreSQL RDS usa cifrado, credenciales maestras administradas y copias automáticas.
RDS transaccional es Multi-AZ en ambos entornos; RDS histórico solo en PROD.
Redis usa cifrado, TLS y autenticación IAM; PROD tiene primario/réplica con
conmutación por fallo y DEV un nodo. Se configuran protección contra eliminación
y snapshots finales de RDS en PROD. Se crean tres secretos de aplicación sin
valores; la administración de bases de datos debe cargar credenciales restringidas
fuera de Terraform. Los roles EC2 no pueden leer secretos maestros de RDS.
No se implementa ETL histórico.

### Almacenamiento, endpoints y logs

CloudFront OAC firma solicitudes al origen REST privado de S3, con versionado y
SSE-S3; el bucket concede lectura a la distribución específica. No es un sitio
web de S3. Los artefactos y logs de ALB usan buckets privados separados. Las
aplicaciones no tienen permiso de lectura del origen estático. El endpoint
gateway de S3 usa tablas privadas de la VPC principal y una política acotada para
artefactos/paquetes de inicialización. Los endpoints de interfaz de Secrets Manager
usan ENI privadas en ambas AZ, DNS privado y Security Groups en 443; su política
cubre los secretos de aplicación. La VPC histórica no tiene endpoints.

CloudWatch Agent se configura para logs de ejecución/inicialización en grupos
por aplicación: retención de 14 días en DEV y 90 en PROD. Los logs de acceso de
ALB se envían a un bucket privado SSE-S3. La configuración no prueba la entrega;
consulta la matriz de validación.

El certificado ACM regional cubre `*.environment.domain`. CloudFront usa su
hostname/certificado AWS, evitando un certificado ACM en us-east-1. La nomenclatura
sigue `nombreRecurso-proyecto-operacion-num-region`, con prefijos compactos para
ALB/target groups y un componente numérico de cuenta para buckets.

El bootstrap independiente provisiona estado S3 cifrado con KMS y versionado,
bloqueo nativo S3, GitHub OIDC y roles acotados de plan/despliegue. Los tfvars por
entorno parametrizan la raíz compartida; los módulos priorizan AWS. Consulta
[bootstrap](BOOTSTRAP.md), [despliegue](DEPLOYMENT.md) y [decisiones](DECISIONS.md).

Referencias AWS: [restricciones de peering](https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-basics.html),
[OAC](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html),
[requisitos del bucket de logs ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html).

---

# English

## Architecture

See the [diagram](diagrams/architecture.svg) and its [Mermaid source](diagrams/architecture.mmd).
Regional workloads target `ca-central-1`; CloudFront and IAM are global services.
Separate accounts host DEV (`develop`) and PROD (`main`). No real AWS deployment has occurred.

### Network layout

| Environment | Primary VPC | Historical VPC |
| --- | --- | --- |
| DEV | 10.10.0.0/16 | 10.11.0.0/16 |
| PROD | 10.20.0.0/16 | 10.21.0.0/16 |

Within each primary /16, /24 subnet third-octet offsets are 0/1 for public
ALB/NAT, 10/11 for applications, 20/21 for transactional RDS, 30/31 for Redis,
and 40/41 for interface endpoints. Historical VPCs use offsets 20/21 for RDS.
Two explicit AZ IDs are inputs; validate them and CIDR compatibility per account.

Public subnets route to the Internet Gateway. Application subnets use same-AZ
NAT gateways in PROD and one shared NAT in DEV. Database/cache tiers have no
Internet default route. Reciprocal peering routes connect only application and
historical subnet CIDRs. Peering does not provide transitive NAT or S3 gateway access.

### Applications and data

The four workloads are frontsite, backoffice, webapi and gameapi. DEV has one EC2
per workload (four total, distributed across two AZs); PROD has two per workload
(eight total, one replica per AZ). Fixed replicas provide redundancy without
Auto Scaling or automatic instance replacement. DEV accepts application/NAT
single points of failure. The challenge's four-EC2 cost reference is not equivalent
to PROD per-workload multi-AZ availability.

ALB uses HTTPS host routing to EC2 port 8080; port 80 redirects to 443. Unmatched
requests receive 403. Backoffice also requires operator CIDRs; an empty list
creates no forwarding rule. EC2 has no public IP or SSH, requires IMDSv2 and
encrypted EBS. Security Groups isolate applications; tier NACLs include request
and ephemeral return traffic. Webapi/gameapi reach transactional RDS (5432) and
Redis (6379); backoffice reaches historical RDS (5432). Frontsite has no database access.

PostgreSQL RDS is encrypted with managed master credentials and automated backups.
Transactional RDS is Multi-AZ in both environments; historical RDS is Multi-AZ
only in PROD. Redis uses encryption, TLS and IAM authentication; PROD has a
primary/replica with failover, DEV one node. PROD data deletion protection and
final RDS snapshots are configured. Three application secrets are created without
values; database administration must populate restricted credentials outside
Terraform. EC2 roles cannot read RDS master secrets. No historical ETL is implemented.

### Storage, endpoints and logs

CloudFront OAC signs requests to the private, versioned SSE-S3 REST origin;
the bucket grants reads to the specific distribution. It is not an S3 website.
Artifacts and ALB logs use separate private buckets. Applications have no static
origin read grant. The S3 gateway endpoint uses primary private route tables and
a scoped policy for artifacts/bootstrap packages. Secrets Manager interface
endpoints use private ENIs in both AZs, private DNS and Security Groups on 443;
their policy covers application secrets. The historical VPC has no endpoints.

CloudWatch Agent is configured for runtime/bootstrap logs in per-application
groups: 14-day DEV and 90-day PROD retention. ALB access logs target a private
SSE-S3 bucket. Configuration is not proof of delivery; see the validation matrix.

The regional ACM certificate covers `*.environment.domain`. CloudFront uses its
AWS hostname/certificate, avoiding an ACM certificate in us-east-1. Naming follows
`nombreRecurso-proyecto-operacion-num-region`, with compact ALB/target-group
prefixes and an account-based numeric bucket component.

The separate bootstrap provisions KMS-encrypted/versioned S3 state, native S3
locking, GitHub OIDC and scoped plan/deploy roles. Environment tfvars parameterize
the shared root; subsystem modules remain AWS-first. See [bootstrap](BOOTSTRAP.md),
[deployment](DEPLOYMENT.md) and [decisions](DECISIONS.md).

AWS references: [peering restrictions](https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-basics.html),
[OAC](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html),
[ALB log bucket requirements](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html).
