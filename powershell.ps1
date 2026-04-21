# AI written i didnt try it yet
# Define the array of vSphere folder names
$folderNames = @("Folder_A", "Folder_B", "Folder_C")

foreach ($folderName in $folderNames) {
    Write-Host "Scanning folder: $folderName" -ForegroundColor Cyan
    
    # Get all VMs within the current folder
    $vms = Get-Folder -Name $folderName | Get-VM
    
    foreach ($vm in $vms) {
        Write-Host "Processing VM: $($vm.Name)"
        
        # Ensure the VM is powered off to safely modify disks
        if ($vm.PowerState -ne "PoweredOff") {
            Write-Host "  [!] Skipping $($vm.Name): VM is powered on. Please shut it down first." -ForegroundColor Yellow
            continue
        }

        # Get the hard disks attached to the VM
        $disks = Get-HardDisk -VM $vm
        
        # Verify the VM only has exactly 1 disk as per your requirement
        if ($disks.Count -eq 1) {
            $targetDisk = $disks[0]
            
            # Save the existing disk's properties so we can recreate it identically
            $diskCapacityGB = $targetDisk.CapacityGB
            $diskDatastore = $targetDisk.Datastore
            $diskFormat = $targetDisk.StorageFormat

            Write-Host "  -> Found Disk: $($targetDisk.Name) | Size: ${diskCapacityGB}GB | Datastore: $diskDatastore"
            
            # 1. DELETE THE DISK (DeletePermanently removes the VMDK from the datastore)
            Write-Host "  -> Deleting disk..." -ForegroundColor Red
            Remove-HardDisk -HardDisk $targetDisk -DeletePermanently -Confirm:$false
            
            # 2. CREATE THE NEW DISK
            Write-Host "  -> Creating and attaching new disk..." -ForegroundColor Green
            New-HardDisk -VM $vm -CapacityGB $diskCapacityGB -Datastore $diskDatastore -StorageFormat $diskFormat -Confirm:$false | Out-Null
            
            Write-Host "  [+] Success for $($vm.Name)" -ForegroundColor Green
        } else {
            Write-Host "  [!] Skipping $($vm.Name): Found $($disks.Count) disks, expected exactly 1." -ForegroundColor Yellow
        }
    }
}