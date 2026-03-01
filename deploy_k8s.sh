#!/bin/bash
set -e

echo "🧹清理集群"
sudo kubeadm reset -f

echo "开启ipv4，ipv6的转发功能"
sudo modprobe br_netfilter
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.ipv4.ip_forward=1

echo "关闭swap"
sudo swapoff -a

echo "启动集群"
# sudo kubeadm init --cri-socket=unix:///run/containerd/containerd.sock --pod-network-cidr=10.244.0.0/16
sudo kubeadm init --config kubeadm-config.yaml

mkdir -p $HOME/.kube
sudo cp  /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "允许主节点运行任务"
kubectl taint nodes server node-role.kubernetes.io/control-plane:NoSchedule-

#echo "标记节点可运行pt容器"
#kubectl label node server nvidia.com/gpu.workload.config=vm-passthrough

echo "修改容忍度"
CONFIG_FILE="/var/lib/kubelet/config.yaml"

if ! grep -q "evictionHard:" $CONFIG_FILE; then
echo "==== 追加 evictionHard 配置到 $CONFIG_FILE ===="
sudo bash -c "cat >> $CONFIG_FILE <<'EOF'
evictionHard:
  nodefs.available: "5%"
  imagefs.available: "5%"
EOF"
else
  echo "==== 已存在 evictionHard 配置，跳过追加 ===="
fi

echo "重启 kubelet"
sudo systemctl restart kubelet

echo "部署flannel插件"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml || true
