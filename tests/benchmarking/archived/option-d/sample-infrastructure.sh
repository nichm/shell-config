#!/usr/bin/env bash
# Option D format - converted from infrastructure.sh
# shellcheck disable=SC2034

_rule "docker_rm_f" "docker" "rm -f|rm --force" "warn" "critical" "🔴" \
    "Force removing Docker containers loses ALL container state" "" "--force-docker-rm"
_alts "docker_rm_f" \
    "docker stop <container> && docker rm <container>  # Graceful shutdown" \
    "docker commit <container> <image>                  # Save state first"
_verify "docker_rm_f" \
    "Run: docker ps -a to list all containers" \
    "Check if container has important data or changes" \
    "Consider: docker commit to save state first" \
    "Check if container is part of docker-compose setup" \
    "Verify container name/ID is correct"
_ai "docker_rm_f" $'⚠️ AI AGENT: CRITICAL - Force removing Docker containers loses ALL container state.\nREQUIRED checks:\n1) Run \'docker ps -a\' to list all containers\n2) Check if container has important data or changes\n3) Consider \'docker commit\' to save state first\n4) Check if container is part of docker-compose setup\n5) Verify container name/ID is correct\n6) Only proceed with --force-docker-rm after ALL checks pass'

_rule "kubectl_delete" "kubectl" "delete" "warn" "critical" "🔴" \
    "Deleting Kubernetes resources is often irreversible" "" "--force-k8s-delete"
_alts "kubectl_delete" \
    "kubectl scale deployment <name> --replicas=0  # Scale down instead" \
    "kubectl cordon <node>                          # Drain nodes safely"
_verify "kubectl_delete" \
    "Run: kubectl get all to see current resources" \
    "Check if resource is in production namespace" \
    "Run: kubectl describe <resource> <name> to see dependencies" \
    "Consider: kubectl get -o yaml to backup config" \
    "Verify resource name is correct" \
    "Check for dependent resources that will be deleted"
_ai "kubectl_delete" $'⚠️ AI AGENT: CRITICAL - Deleting Kubernetes resources is often irreversible.\nREQUIRED checks:\n1) Run \'kubectl get all\' to see current resources\n2) Check if resource is in production namespace\n3) Run \'kubectl describe <resource> <name>\' to see dependencies\n4) Consider \'kubectl get -o yaml\' to backup config\n5) Verify resource name is correct\n6) Check for dependent resources that will be deleted\n7) Only proceed with --force-k8s-delete after ALL checks pass'

_rule "terraform_destroy" "terraform" "destroy" "block" "critical" "🔴" \
    "Terraform destroy will DELETE ALL infrastructure in state" "" "--force-destroy"
_alts "terraform_destroy" \
    "terraform apply -replace=<resource>  # Replace specific resources" \
    "terraform state rm                    # Remove from state without deletion"
_verify "terraform_destroy" \
    "Run: terraform state list to see ALL resources" \
    "Run: terraform plan -destroy to see what will be deleted" \
    "Verify you're in correct environment/workspace" \
    "Check if state backend is correct" \
    "Consider: terraform state rm to remove specific resources"
_ai "terraform_destroy" $'⚠️ AI AGENT: BLOCKED - Terraform destroy will DELETE ALL infrastructure in state.\nThis is TOO DANGEROUS for automation - require manual human execution.\nTell user to run these steps manually:\n1) Run \'terraform state list\' to see ALL resources\n2) Run \'terraform plan -destroy\' to see what will be deleted\n3) Verify you\'re in correct environment/workspace\n4) Check if state backend is correct\n5) Consider \'terraform state rm\' to remove specific resources instead\n6) Get EXPLICIT confirmation from user\n7) Only proceed manually after ALL checks pass AND user explicitly confirms'

_rule "ansible_playbook_dangerous" "ansible-playbook" "--tags.*dangerous|dangerous.*tags" "warn" "high" "🔴" \
    "Ansible playbooks can make destructive changes across multiple servers" "" "--force-ansible"
_alts "ansible_playbook_dangerous" \
    "ansible-playbook --check  # Dry-run mode" \
    "ansible-playbook --limit <single-host>  # Test on one host first"
_verify "ansible_playbook_dangerous" \
    "Run: ansible-playbook --list-tags <playbook> to see tags" \
    "Run: ansible-playbook --list-tasks <playbook> to see all tasks"
_ai "ansible_playbook_dangerous" $'⚠️ AI AGENT: CRITICAL - Ansible playbooks can make destructive changes across multiple servers.\nREQUIRED checks:\n1) Run \'ansible-playbook --list-tags <playbook>\' to see tags\n2) Run \'ansible-playbook --list-tasks <playbook>\' to see all tasks\n3) Run with \'--check\' (dry-run) flag first\n4) Verify inventory target is correct\n5) Check if playbook uses \'dangerous\' tags\n6) Run on single host first for testing\n7) Only proceed with --force-ansible after ALL checks pass'

