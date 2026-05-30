# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Kata Containers（GPU 直通）与 runc 的 Kubernetes 性能对比测试。通过 NVIDIA GPU（`nvidia.com/pgpu`）直通，在 Kata QEMU 虚拟机和原生 runc 之间对比 CPU、内存、网络、文件 IO、系统调用和容器启动时间。

## 常用命令

```bash
# 启动/删除 Pod
kubectl apply -f <pod.yaml>
kubectl delete -f <pod.yaml>

# 检查 Pod 状态
kubectl get pod <pod-name> -o wide
kubectl describe pod <pod-name>

# 查看日志
kubectl logs <pod-name>

# 进入容器（Kata/QEMU Pod）
kubectl exec -it <pod-name> -- bash

# 查看 Kata sandbox/QEMU 进程
crictl pods --name <pod-name> -q          # 获取 sandbox ID
ps aux | grep qemu-system | grep <sandbox-id>

# 获取 Pod UID
kubectl get pod <pod-name> -o jsonpath='{.metadata.uid}'

# vllm-perf 性能测量（perf 采样 QEMU 进程）
cd vllm-perf
PERF_DURATION=30 PERF_RECORD=0 ./per.sh   # perf stat 默认 30 秒
PERF_DURATION=60 PERF_RECORD=1 ./per.sh   # 60 秒 + perf record

# 获取节点 GPU 信息
kubectl describe node server | grep nvidia
```

## 目录结构

```
kata-pgpu/
├── benchscript/           # 系统性能对比基准测试（kata vs runc）
│   ├── kata/              #   Kata QEMU 运行时测试 + result/
│   └── runc/              #   runc 运行时测试 + result/
├── vllm-perf/             # vLLM 推理 GPU Pod + perf 测量脚本
├── logs/                  # containerd/kubelet/sys 日志（用于调试）
├── kata-containers/       # 上游 Kata Containers 3.31.0 源码（非自定义）
├── *.yaml                 # 根目录下的 Pod 定义（GPU vectoradd、fio、smoke 等）
└── *.log                  # 权重加载基准测试结果
```

## RuntimeClass 与 GPU 配置

- **`kata-qemu-nvidia-gpu`**: Kata QEMU 虚拟机 + NVIDIA GPU 直通，所有 GPU 测试使用此 runtime
- **`kata-qemu`**: 纯 Kata QEMU 虚拟机，无 GPU（仅 `kata-smoke.yaml` 使用）
- **`runc`**: 标准 runc 容器运行时
- 节点选择: `server`（容忍 `nvidia.com/pgpu` NoSchedule 污点）
- GPU 资源: `nvidia.com/pgpu: 1`（limits + requests）
- GPU 设备插件: `nvidia-kata-sandbox-device-plugin-noinit.yaml`（DaemonSet）

## 挂载路径

所有 Pod 共享以下 hostPath 卷:
- **模型**: `/home/liulei/models/Qwen/Qwen3___5-9B` → `/model`（只读）
- **跟踪**: `/data/home/liulei/TcProject/ctr-container/traces` → `/traces`（读写）

## 基准测试维度（benchscript/）

Kata 和 runc 之间的 7 项对比测试，每项都有配对的 YAML 定义:

| 测试 | 工具 | 示例文件 |
|------|------|----------|
| CPU | sysbench / stress-ng | `runtime-sysbench-cpu.yaml` |
| 内存 | sysbench / stress-ng | `runtime-sysbench-memory.yaml` |
| 网络 | iperf3 | `iperf3-server.yaml` + `runtime-iperf3-client.yaml` |
| 磁盘 IO | fio | `runtime-fio-randrw.yaml` |
| 系统调用 | stress-ng | `runtime-syscall-stress-ng.yaml` |
| 启动时间 | alpine `true` | `runtime-startup-alpine.yaml` |
| 权重加载 | dd | `kata-fio.yaml` / `runc-fio.yaml` |

iperf3 测试需要先启动 server Pod，再运行 client Job。

## 已知问题

- QEMU `vhost-user-fs-pci.cache-size` 属性不识别，导致 Kata 沙箱创建失败。修复方式: 编辑 `/opt/kata/share/defaults/kata-containers/runtimes/qemu-nvidia-gpu/configuration-qemu-nvidia-gpu.toml`，移除有问题的参数。
