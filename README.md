# OSX-For-Windows
First check that you've [enabled Hyper-V](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v) before proceeding.
- You can enable the Hyper-V role by running the below command in PowerShell as administrator:
  ```ps
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
  ```
- After rebooting, you can check that you've successfully enabled Hyper-V by running:
  ```ps
  Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
  ```
![20240827183758](https://github.com/user-attachments/assets/35616bd7-e747-4a7e-9197-c5efd2bc5df2)

Run Disk Utility to erase your virtual disk
![20240827211608](https://github.com/user-attachments/assets/c9184c4f-abb2-43ea-be36-9dcc20ca3942)

Reinstall macOS Monterey. Enjoy it.
Thanks to balopez83
