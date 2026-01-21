.PHONY: init plan apply destroy

# SOPS config
SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
export SOPS_AGE_KEY_FILE

SECRETS_FILE = secrets.yaml
TF_DIR = .

init:
	cd $(TF_DIR) && terraform init

plan: _check-secrets
	@NAMECHEAP_USERNAME=$$(sops -d $(SECRETS_FILE) | yq '.namecheap_username') && \
	NAMECHEAP_API_KEY=$$(sops -d $(SECRETS_FILE) | yq '.namecheap_api_key') && \
	cd $(TF_DIR) && terraform plan \
		-var="namecheap_username=$$NAMECHEAP_USERNAME" \
		-var="namecheap_api_key=$$NAMECHEAP_API_KEY"

apply: _check-secrets
	@NAMECHEAP_USERNAME=$$(sops -d $(SECRETS_FILE) | yq '.namecheap_username') && \
	NAMECHEAP_API_KEY=$$(sops -d $(SECRETS_FILE) | yq '.namecheap_api_key') && \
	cd $(TF_DIR) && terraform apply \
		-var="namecheap_username=$$NAMECHEAP_USERNAME" \
		-var="namecheap_api_key=$$NAMECHEAP_API_KEY"

destroy: _check-secrets
	@NAMECHEAP_USERNAME=$$(sops -d $(SECRETS_FILE) | yq '.namecheap_username') && \
	NAMECHEAP_API_KEY=$$(sops -d $(SECRETS_FILE) | yq '.namecheap_api_key') && \
	cd $(TF_DIR) && terraform destroy \
		-var="namecheap_username=$$NAMECHEAP_USERNAME" \
		-var="namecheap_api_key=$$NAMECHEAP_API_KEY"

_check-secrets:
	@if [ ! -f $(SECRETS_FILE) ]; then \
		echo "Error: $(SECRETS_FILE) not found. Copy from secrets.yaml.example and encrypt with sops."; \
		exit 1; \
	fi
