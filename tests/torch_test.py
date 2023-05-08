import torch

print("PyTorch version:", torch.__version__)

print("CUDA available:", torch.cuda.is_available())

print("CUDA version:", torch.version.cuda)

print("Compute capability:", torch.cuda.get_arch_list())

print("Total GPUs:", torch.cuda.device_count())

print("Device Name:", torch.cuda.get_device_name())
print()

t1 = torch.tensor([0,1,2]).to('cuda')
print("T1:", t1)
t2 = torch.tensor([2,1,0]).to('cuda')
print("T2:", t2)

try:
    t3 = t2 + t1
except Exception as e:
    print(e)

print("T1+T2:", t3)
