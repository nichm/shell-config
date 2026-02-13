#!/usr/bin/env bash
# Option E format - converted from infrastructure.sh
# shellcheck disable=SC2034

_R id="docker_rm_f" cmd="docker" pat="rm -f|rm --force" act="warn" lvl="critical" \
   em="🔴" desc="Force removing Docker containers loses ALL container state" docs="" byp="--force-docker-rm"
_A "docker_rm_f" "docker stop <container> && docker rm <container>  # Graceful shutdown" "docker commit <container> <image>                  # Save state first"
_V "docker_rm_f" "Run: docker ps -a to list all containers" "Check if container has important data or changes" "Consider: docker commit to save state first" "Check if container is part of docker-compose setup" "Verify container name/ID is correct"
_W "docker_rm_f" $'⚠️ AI AGENT: CRITICAL - Force removing Docker containers loses ALL container state.\nREQUIRED checks:\n1) Run \'docker ps -a\' to list all containers\n2) Check if container has important data or changes\n3) Consider \'docker commit\' to save state first\n4) Check if container is part of docker-compose setup\n5) Verify container name/ID is correct\n6) Only proceed with --force-docker-rm after ALL checks pass'

_R id="kubectl_delete" cmd="kubectl" pat="delete" act="warn" lvl="critical" \
   em="🔴" desc="Deleting Kubernetes resources is often irreversible" docs="" byp="--force-k8s-delete"
_A "kubectl_delete" "kubectl scale deployment <name> --replicas=0  # Scale down instead" "kubectl cordon <node>                          # Drain nodes safely"
_V "kubectl_delete" "Run: kubectl get all to see current resources" "Check if resource is in production namespace" "Run: kubectl describe <resource> <name> to see dependencies" "Consider: kubectl get -o yaml to backup config" "Verify resource name is correct" "Check for dependent resources that will be deleted"
_W "kubectl_delete" $'⚠️ AI AGENT: CRITICAL - Deleting Kubernetes resources is often irreversible.\nREQUIRED checks:\n1) Run \'kubectl get all\' to see current resources\n2) Check if resource is in production namespace\n3) Run \'kubectl describe <resource> <name>\' to see dependencies\n4) Consider \'kubectl get -o yaml\' to backup config\n5) Verify resource name is correct\n6) Check for dependent resources that will be deleted\n7) Only proceed with --force-k8s-delete after ALL checks pass'

_R id="terraform_destroy" cmd="terraform" pat="destroy" act="block" lvl="critical" \
   em="🔴" desc="Terraform destroy will DELETE ALL infrastructure in state" docs="" byp="--force-destroy"
_A "terraform_destroy" "terraform apply -replace=<resource>  # Replace specific resources" "terraform state rm                    # Remove from state without deletion"
_V "terraform_destroy" "Run: terraform state list to see ALL resources" "Run: terraform plan -destroy to see what will be deleted" "Verify you're in correct environment/workspace" "Check if state backend is correct" "Consider: terraform state rm to remove specific resources"
_W "terraform_destroy" $'⚠️ AI AGENT: BLOCKED - Terraform destroy will DELETE ALL infrastructure in state.\nThis is TOO DANGEROUS for automation - require manual human execution.\nTell user to run these steps manually:\n1) Run \'terraform state list\' to see ALL resources\n2) Run \'terraform plan -destroy\' to see what will be deleted\n3) Verify you\'re in correct environment/workspace\n4) Check if state backend is correct\n5) Consider \'terraform state rm\' to remove specific resources instead\n6) Get EXPLICIT confirmation from user\n7) Only proceed manually after ALL checks pass AND user explicitly confirms'

_R id="ansible_playbook_dangerous" cmd="ansible-playbook" pat="--tags.*dangerous|dangerous.*tags" act="warn" lvl="high" \
   em="🔴" desc="Ansible playbooks can make destructive changes across multiple servers" docs="" byp="--force-ansible"
_A "ansible_playbook_dangerous" "ansible-playbook --check  # Dry-run mode" "ansible-playbook --limit <single-host>  # Test on one host first"
_V "ansible_playbook_dangerous" "Run: ansible-playbook --list-tags <playbook> to see tags" "Run: ansible-playbook --list-tasks <playbook> to see all tasks"
_W "ansible_playbook_dangerous" $'⚠️ AI AGENT: CRITICAL - Ansible playbooks can make destructive changes across multiple servers.\nREQUIRED checks:\n1) Run \'ansible-playbook --list-tags <playbook>\' to see tags\n2) Run \'ansible-playbook --list-tasks <playbook>\' to see all tasks\n3) Run with \'--check\' (dry-run) flag first\n4) Verify inventory target is correct\n5) Check if playbook uses \'dangerous\' tags\n6) Run on single host first for testing\n7) Only proceed with --force-ansible after ALL checks pass'

