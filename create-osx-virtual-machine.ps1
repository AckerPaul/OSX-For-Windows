## @file
# Hyper-V virtual machine creation script
#
# Copyright (c) 2023, Cory Bennett. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
##

param (
  [string]$pwd = "$((Get-Item "$PSScriptRoot\..").FullName)",
  # Script arguments
  [string]$name = "macOS",
  [string]$version = "latest",
  [int]$cpu = 2,
  [int]$ram = 8,    # Size in GB
  [int]$size = 50,  #
  [string]$outdir = "$env:USERPROFILE\Documents\Hyper-V"
)

# Prompt for Administrator priviledges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList ("-noprofile -file `"{0}`" -elevated -pwd $pwd -name $name -version $version -cpu $cpu -ram $ram -size $size -outdir $outdir" -f ($myinvocation.MyCommand.Definition));
  exit;
}

function Connect-VM {
  [CmdletBinding(DefaultParameterSetName = 'name')]

  param(
    [Parameter(ParameterSetName = 'name')]
    [Alias('cn')]
    [System.String[]]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Position = 0,
      Mandatory, ValueFromPipelineByPropertyName,
      ValueFromPipeline, ParameterSetName = 'name')]
    [Alias('VMName')]
    [System.String]$Name,

    [Parameter(Position = 0,
      Mandatory, ValueFromPipelineByPropertyName,
      ValueFromPipeline, ParameterSetName = 'id')]
    [Alias('VMId', 'Guid')]
    [System.Guid]$Id,

    [Parameter(Position = 0, Mandatory,
      ValueFromPipeline, ParameterSetName = 'inputObject')]
    [Microsoft.HyperV.PowerShell.VirtualMachine]$InputObject,

    [switch]$StartVM
  )

  begin {
    Write-Verbose "Initializing InstanceCount, InstanceCount = 0"
    $InstanceCount = 0
  }

  process {
    try {
      foreach ($computer in $ComputerName) {
        Write-Verbose "ParameterSetName is '$($PSCmdlet.ParameterSetName)'"
        if ($PSCmdlet.ParameterSetName -eq 'name') {
          # Get the VM by Id if Name can convert to a guid
          if ($Name -as [guid]) {
            Write-Verbose "Incoming value can cast to guid"
            $vm = Get-VM -Id $Name -ErrorAction SilentlyContinue
          } else {
            $vm = Get-VM -Name $Name -ErrorAction SilentlyContinue
          }
        } elseif ($PSCmdlet.ParameterSetName -eq 'id') {
          $vm = Get-VM -Id $Id -ErrorAction SilentlyContinue
        } else {
          $vm = $InputObject
        }
        if ($vm) {
          Write-Verbose "Executing 'vmconnect.exe $computer $($vm.Name) -G $($vm.Id) -C $InstanceCount'"
          vmconnect.exe $computer $vm.Name -G $vm.Id -C $InstanceCount
        } else {
          Write-Verbose "Cannot find vm: '$Name'"
        }
        if ($StartVM -and $vm) {
          if ($vm.State -eq 'off') {
            Write-Verbose "StartVM was specified and VM state is 'off'. Starting VM '$($vm.Name)'"
            Start-VM -VM $vm
          } else {
            Write-Verbose "Starting VM '$($vm.Name)'. Skipping, VM is not not in 'off' state."
          }
        }
        $InstanceCount += 1
        Write-Verbose "InstanceCount = $InstanceCount"
      }
    } catch {
      Write-Error $_
    }
  }
}

# Create new virtual machine
New-VM -Generation 2 -Name "$name" -path "$outdir" -NoVHD | Out-Null

# Configure network adapter to use the default vswitch
$networkAdapter = Get-VMNetworkAdapter -VMName "$name"
Connect-VMNetworkAdapter -VMName "$name" -Name "$($networkAdapter.name)" -SwitchName "Default Switch"

# Create EFI disk
$efiVHD = "D:\vhd\UEFI.vhdx"
Add-VMHardDiskDrive -VMName "$name" -Path "$efiVHD" -ControllerType SCSI
$efiDisk = Get-VMHardDiskDrive -VMName "$name"

# Create post-install VHDX if tools folder is present
$toolsDir = "$($pwd)\Tools"
if (Test-Path -Path "$toolsDir") {
  $toolsVHD = "$outdir\$name\Tools.vhdx" 
  # Create and mount a new tools.vhdx disk
  $toolsDisk = New-VHD -Path "$toolsVHD" -Dynamic -SizeBytes 512MB |
    Mount-VHD -Passthru |
    Initialize-Disk -PartitionStyle "GPT" -Confirm:$false -Passthru |
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem "FAT32" -NewFileSystemLabel "Tools" -Confirm:$false -Force
  # Copy tools folder contents
  Copy-Item -Path "$toolsDir\*" -Recurse -Destination "$($toolsDisk.DriveLetter):\"
  # Unmount VHDX disk
  Dismount-DiskImage -ImagePath "$toolsVHD" | Out-Null
  # Add VHDX disk to virtual machine
  Add-VMHardDiskDrive -VMName "$name" -Path "$toolsVHD" -ControllerType SCSI
}

# Create macOS disk
$macOSVHD = "$outdir\$name\$name.vhdx" 
New-VHD -SizeBytes $($size*1GB) -Path "$macOSVHD" | Out-Null
Add-VMHardDiskDrive -VMName "$name" -Path "$macOSVHD" -ControllerType SCSI
Set-VM -Name "$name" -CheckpointType Disabled
Connect-VM -VMName "$name"

# Configure virtual machine
Set-VM `
  -Name "$name" `
  -ProcessorCount $cpu `
  -MemoryStartupBytes $($ram*1GB) `
  -AutomaticCheckpointsEnabled $false
Set-VMFirmware -VMName "$name" `
  -EnableSecureBoot Off `
  -FirstBootDevice $efiDisk
