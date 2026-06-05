### 2026-06-02: Added Ansible provisioner for Hearth bootstrap
**By:** Vincent Huybrechts (via Kaylee)
**What:** Added hearth_ansible provisioner to ws-haven.yaml, uncommented hearth_bootstrap stage in deploy-haven-prd.yaml, added HEARTH_SSH_PRIVATE_KEY secret to env-haven-prd.yaml.
**Why:** AnsibleDeployer in strata v0.0.6 is fully implemented. Hearth bootstrap needs Docker install + directory setup + compose deploy via Ansible.
