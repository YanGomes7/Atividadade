# Avaliação Prática de DevOps — Cadastro de Produtos (Prova A)

## Integrantes do grupo
- **NOME COMPLETO DO INTEGRANTE 1**
- **NOME COMPLETO DO INTEGRANTE 2**
- **NOME COMPLETO DO INTEGRANTE 3**

## Arquitetura
- **VM1**: Docker com Nginx servindo `index.html` (formulário + link "Listar todos os produtos").
- **VM2**: Docker Compose com API Node.js (Express) + MySQL 8.
- A VM1 consome a API da VM2 via HTTP (`POST /produto`, `GET /produtos`). CORS configurado na API (origem da VM1; métodos GET, POST e OPTIONS).
- **QEMU/KVM (libvirt)**: OpenTofu cria as 2 VMs, cloud-init instala o Docker e cria o usuário `ubuntu` com a chave SSH, Ansible implanta os serviços.

## Como executar
Pré-requisitos: QEMU/KVM + libvirt (`libvirtd` ativo, rede `default` ativa), OpenTofu, Ansible e par de chaves SSH (`~/.ssh/id_rsa[.pub]`).

```bash
# 1. Provisionar as VMs (também gera ansible/inventory com os IPs)
cd iac
tofu init
tofu apply -auto-approve

# 2. Implantar os serviços
cd ../ansible
ansible-playbook -i inventory playbook.yml
```

## Acesso
- Aplicação web: `http://<IP_VM1>/` (IP exibido em `tofu output vm1_ip`)
- API: `http://<IP_VM2>:3000/produtos`

## Teste rápido da API
```bash
curl -X POST http://<IP_VM2>:3000/produto -H 'Content-Type: application/json' \
  -d '{"nome":"Mouse","categoria":"Periféricos","preco":59.9,"quantidade":10}'
curl http://<IP_VM2>:3000/produtos
```
# Atividadade
# Atividadade
