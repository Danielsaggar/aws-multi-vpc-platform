# Reto Ingeniero Cloud 
![Logo de Promarketing](https://promarketingchile.com/wp-content/uploads/2020/03/Logo-promarketing.jpeg)

## **¡Te damos la bienvenida al desafío de Promarketing Chile!**

Si has llegado hasta aquí, es porque tu perfil nos ha impresionado y creemos que tienes el potencial para ser una pieza clave en nuestro equipo.
Este reto ha sido diseñado para que demuestres tu capacidad técnica, criterio arquitectónico y enfoque en buenas prácticas Cloud.

Queremos ver cómo piensas, cómo estructuras soluciones y cómo aplicas los principios de seguridad, escalabilidad y automatización en entornos reales.
Más que líneas de código, buscamos entender tu forma de diseñar, optimizar y proteger infraestructura en la nube.

## Diseño y Aprovisionamiento de Infraestructura en AWS para un Casino Online

---

## Introducción

El propósito de este desafío es evaluar tus habilidades en el diseño y despliegue de infraestructura en AWS.  
Deberás planificar y aprovisionar desde cero una **“Operación de Casino Online”**, aplicando buenas prácticas de seguridad, escalabilidad y organización de código.

> - No es obligatorio tener acceso a una cuenta AWS; el foco principal es **la planificación y el código Terraform**.  
> - Si decides desplegar la infraestructura, puedes incluir los resultados como anexo o evidencia adicional.

---

## Requisitos de la Operación

La operación del negocio se basa en una **arquitectura de microservicios**.  
A continuación se detallan los componentes principales que debes implementar:

### Región
Toda la infraestructura debe ser desplegada en la región:  
**`ca-central-1` (Canadá).**

---

### VPCs
- **2 VPCs conectadas por VPC Peering:**
  - **VPC Principal:** aplicaciones, frontend, APIs y servicios públicos.
  - **VPC Secundaria:** bodega de datos (base histórica).

---

### Subredes
- Subredes **públicas y privadas** distribuidas en **múltiples Zonas de Disponibilidad (AZs)** para asegurar **alta disponibilidad**.  
- Las instancias de aplicación (EC2) y bases de datos deben residir en **subredes privadas**.

---

### Gateways
- **Internet Gateway (IGW)**: permite tráfico público saliente/entrante.  
- **NAT Gateway con Elastic IP:** habilita a las instancias privadas acceso a Internet saliente.

---

### Balanceo de Carga
- Implementar un **Application Load Balancer (ALB)** con certificado **SSL/TLS** emitido por **AWS Certificate Manager (ACM)**.  
- El tráfico entrante desde Internet debe ser gestionado por el ALB, redirigiendo a las instancias EC2 privadas.

---

### Servidores de Aplicación (EC2)
- Crear instancias para las siguientes aplicaciones:
  - `frontsite`
  - `backoffice`
  - `webapi`
  - `gameapi`
- Todas deben estar en **subredes privadas**, detrás del balanceador.

---

### Bases de Datos
- **RDS** para las operaciones principales (transaccional).
- **RDS o Redshift** en la VPC de bodega de datos (histórica).

---

### Cache
- Implementar **Redis (ElastiCache)** para mejorar el rendimiento y disminuir la latencia.

---

### CDN y Almacenamiento
- **Amazon S3** para contenido estático (imágenes, assets, archivos).
- **CloudFront** como **CDN** para servir este contenido globalmente.

---

### Seguridad
- Uso de **Security Groups** y **Network ACLs** para aislar niveles:
  - Balanceador
  - EC2
  - Redis
  - Bases de datos
- Cumplir con el principio de **menor privilegio** y restringir tráfico entrante/saliente según origen y puerto.

---

### Nomenclatura
Usar el siguiente estándar:
nombreRecurso-proyecto-operacion-num-region 

---

### S3 Privado + CloudFront Origin Access (OAI/OAC)

#### Objetivo
Asegurar que el bucket S3 **no sea público** y que solo **CloudFront** pueda acceder a su contenido.

#### Configuración Requerida
- Crear **Origin Access Identity (OAI)** o **Origin Access Control (OAC)**.  
- Configurar una **política de bucket** que permita acceso **solo al OAI/OAC**.  
- Habilitar **cifrado SSE-S3 o SSE-KMS**.  
- **Bloquear ACLs públicas** y desactivar el acceso anónimo.

---

### VPC Endpoints para S3 y Secrets Manager

#### Objetivo
Permitir que los recursos en **subredes privadas** accedan a S3 o Secrets Manager **sin salir a Internet**.

#### Configuración Requerida
- **Endpoint tipo Gateway** para S3.  
- **Endpoint tipo Interface** para Secrets Manager (y opcionalmente SNS).  
- Asociar los endpoints a las **tablas de enrutamiento** de las subredes privadas.

---

### CloudWatch Logs + ALB Access Logs

#### Objetivo
Implementar observabilidad y trazabilidad en la infraestructura.

#### Configuración Requerida
- Crear **CloudWatch Log Groups** centralizados para EC2 y aplicaciones.  
- Activar **Access Logs** del ALB hacia **S3 o CloudWatch Logs**.  
- (Opcional) Configurar **métricas y alarmas** para errores 5xx o alta latencia.

---

## Entregables

### Proyecto Terraform
Estructura modular que contenga:

/main.tf  
/variables.tf  
/outputs.tf  
/network.tf  
/instances.tf  
/s3.tf  
/cloudfront.tf  
/endpoints.tf  
/monitoring.tf  

> - Código limpio, reutilizable y documentado.


### Diagrama de Arquitectura
Debe incluir:
- Ambas **VPCs** y su **VPC Peering**.  
- Subredes, Gateways, Endpoints.  
- ALB, EC2, RDS, Redis, S3, CloudFront (con OAI/OAC).  
- CloudWatch y logs centralizados.  
> - Puedes usar Draw.io, Lucidchart, Excalidraw, o cualquier herramienta similar.

---

### Calculadora de Costos Mensual

Una hoja de cálculo con desglose por servicio:

| **Servicio**         | **Descripción**                     | **Estimado Mensual (USD)** |
|----------------------|-------------------------------------|-----------------------------|
| EC2                 | 4 instancias en alta disponibilidad  | $xx.xx                      |
| RDS                 | Multi-AZ + backup                    | $xx.xx                      |
| ALB                 | 1 balanceador activo                 | $xx.xx                      |
| NAT Gateway         | 1 instancia con Elastic IP           | $xx.xx                      |
| S3 + CloudFront     | Contenido estático + CDN             | $xx.xx                      |
| Redis (ElastiCache) | Capa de caché                        | $xx.xx                      |
| VPC Endpoints       | S3 + Secrets Manager                 | $xx.xx                      |
| CloudWatch Logs     | Monitoreo y almacenamiento           | $xx.xx                      |
| **Total Estimado**  |                                      | **$xxx.xx**                 |


---

## Consideraciones Finales

- Utiliza al menos **dos Zonas de Disponibilidad (AZs)** para alta disponibilidad.  
- No es necesario implementar **autoescalado** ni **disaster recovery** avanzado.  
- Entrega el desafío como:
  - Archivo `.zip` con todos los archivos, **o**
  - Enlace a un **repositorio público de GitHub**.  
  
## Documentación sugerida:
-  [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
-  [Terraform AWS Modules Registry](https://registry.terraform.io/browse/modules?provider=aws)


