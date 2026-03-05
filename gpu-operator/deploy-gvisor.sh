#! /bin/bash

set -e

#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROM_CONFIG_FILE="$SCRIPT_DIR/prom_values.yaml"
GPU_OPERATOR_CONFIG_FILE="$SCRIPT_DIR/gpu-operator-values.yaml"

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "====================安装gpu-operator===================="
helm install --wait --generate-name  \
    -n gpu-operator --create-namespace  \
    nvidia/gpu-operator \
    -f $GPU_OPERATOR_CONFIG_FILE


echo "====================安装kube-prometheus-stack===================="
helm install prom prometheus-community/kube-prometheus-stack  -n monitoring --create-namespace -f $PROM_CONFIG_FILE


echo "====================创建runtimeClass===================="
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
EOF

cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
EOF


echo "====================修改kubelet cAdvisor config（TODO）===================="
echo "请手动修改"
echo "sudo vim /etc/default/kubelet"
echo "在文件中追加KUBELET_EXTRA_ARGS=--housekeeping-interval=700ms"