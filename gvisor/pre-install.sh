#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROM_CONFIG_FILE="$SCRIPT_DIR/prometheus-config/prom_values.yaml"
DCGM_CONFIG_FILE="$SCRIPT_DIR/dcgm-exporter-config/values.yaml"

helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add dcgm https://nvidia.github.io/dcgm-exporter/helm-charts
helm repo update

echo "====================安装nvidia-device-plugin===================="
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --version=0.18.2 \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --set gfd.enabled=true \
	--set devicePlugin.enabled=true \
	--set compatWithCPUManager=true    # 用于启用PASS_DEVICE_SPECS


echo "====================安装kube-prometheus-stack===================="
helm install prom prometheus-community/kube-prometheus-stack  -n monitoring --create-namespace -f $PROM_CONFIG_FILE

echo "====================安装dcgm-exporter===================="
helm install dcgm dcgm/dcgm-exporter -n monitoring -f $DCGM_CONFIG_FILE


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