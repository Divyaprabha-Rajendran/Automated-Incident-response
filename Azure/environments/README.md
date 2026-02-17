# Per-subscription environments

Each environment is a **separate Terraform root** with its own provider (subscription). State is stored **locally** (`terraform.tfstate` in each directory).

| Environment  | Subscription ID                          |
|-------------|-------------------------------------------|
| **production** | `633d0b44-3342-4bfb-beca-fc7b3322565a` |
| **security**   | `baab7ade-9c09-4160-9794-e18f7d0e6595` |
| **forensics**  | `633d0b44-3342-4bfb-beca-fc7b3322565a` (same as production) |

## Usage

**Production**
```bash
cd environments/production
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
Create `production/terraform.tfvars` with your values (you can copy from `../security/security.tfvars` and adjust).

**Security**
```bash
cd environments/security
terraform init
terraform plan -var-file=security.tfvars
terraform apply -var-file=security.tfvars
```
(Requires `-var="windows_vm_admin_password=..."` when VMs include Windows.)

**Forensics**
```bash
cd environments/forensics
terraform init
terraform plan -var-file=forensics.tfvars
terraform apply -var-file=forensics.tfvars
```
Creates ForensicsRGAutomation with a VNet (no VMs), a storage account, a `snapshots` container, and a Key Vault. Use as the destination for the IncidentResponse runbook.

## Optional: env-specific tfvars

For production, add `production/terraform.tfvars` (or use `-var-file=...`). Security environment has `security.tfvars` in the same folder.
