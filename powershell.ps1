# Path to the VMware Workstation disk manager tool
$vdiskManager = "E:\programs\vmware\miain\vmware-vdiskmanager.exe"

# The size of the NEW blank disks you want to create
$diskSizeGB = 120 

# Your local VM folders
$vmFolders = @(
    "D:\vms\master-0.ocp.koko", 
    "D:\vms\master-1.ocp.koko", 
    "D:\vms\master-2.ocp.koko", 
    "D:\vms\cptnod-0.ocp.koko",
    "D:\vms\bootstrap"
)

# 1. Verify the VMware tool exists
if (-not (Test-Path $vdiskManager)) {
    Write-Host "[!] Cannot find vmware-vdiskmanager.exe. Please check the path." -ForegroundColor Red
    exit
}

$indexfolder = 0
foreach ($folder in $vmFolders) {
    Write-Host "Scanning folder: $folder" -ForegroundColor Cyan

    if (-not (Test-Path $folder)) {
        Write-Host "  [!] Skipping: Folder does not exist." -ForegroundColor Yellow
        continue
    }

    $vmName = Split-Path $folder -Leaf
    
    # Determine the disk name based on your clone logic
    if ($indexfolder -eq 0) {
        $diskFileName = "master-0.ocp.koko.vmdk"
    } elseif($indexfolder + 1 -eq $vmFolders.Length){
         $diskFileName = "master-0.ocp.koko-cl1.vmdk"
    } else {
        $diskFileName = "master-0.ocp.koko-cl$indexfolder.vmdk"
    }
    
    $mainVmdkPath = Join-Path $folder $diskFileName
    $indexfolder++

    if (Test-Path $mainVmdkPath) {
        Write-Host "  -> Found disk: $mainVmdkPath"
        
        # 2. DELETE the existing disk files
        # FIX: We now delete ALL .vmdk files in this specific folder so there are no conflicts.
        # Your previous logic ($vmName*.vmdk) missed the cloned files.
        Write-Host "  -> Deleting old disk files..." -ForegroundColor Red
        Get-ChildItem -Path $folder -Filter "*.vmdk" | Remove-Item -Force

        # 3. CREATE the new disk
        Write-Host "  -> Creating new ${diskSizeGB}GB Thin (Growable) disk..." -ForegroundColor Green
        
        # Arguments for vdiskmanager: 
        # -c (create)
        # -s (size)
        # -a lsilogic (adapter type)
        # -t 0 (single growable virtual disk -> THIS IS VMWARE WORKSTATION'S "THIN" PROVISIONING)
        $arguments = "-c -s ${diskSizeGB}GB -a lsilogic -t 0 `"$mainVmdkPath`""
        
        $process = Start-Process -FilePath $vdiskManager -ArgumentList $arguments -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "  [+] Success for $vmName" -ForegroundColor Green
        } else {
            Write-Host "  [!] Failed to create disk for $vmName" -ForegroundColor Red
        }

    } else {
        Write-Host "  [!] Could not find primary disk named $diskFileName in $folder." -ForegroundColor Yellow
    }
}