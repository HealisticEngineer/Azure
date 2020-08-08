# Input values
$ResourceGroup = 'TipsForITProsResourceGroup'
$networkname = "myVNET"
$Location = "West US"

# Check or Create Resource Group
if(!(Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue)){
    Write-Warning "resource group does not exist, creating it"
    New-AzResourceGroup -Name $ResourceGroup -Location $location
} else {
    Write-Output "Resource Group Exists"
}


# Get network and create if not existing
if(!(Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)){
    Write-Warning "Network Doesn't exist"
    # Create a subnet configuration
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "mySubnet" -AddressPrefix 192.168.1.0/24
    # Create a virtual network
    $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Location $location -Name $networkname -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig
} else {
    Write-Output "Network Resource Exists"
    $vnet = Get-AzVirtualNetwork -Name $networkname -ResourceGroupName $ResourceGroup
}

# firewall rules
if(!(get-AzNetworkSecurityGroup -Name "LinuxWebServers" -ErrorAction SilentlyContinue)){
    Write-Warning "LinuxWebServers Network Security Rules Don't exist, creating them"

    # Create an inbound network security group rule for port 22
    $sshrule =@{
        Name                    = "myNetworkSecurityGroupRuleSSH"
        Protocol                = "Tcp"
        Direction               = "Inbound"
        Priority                = 1000
        SourceAddressPrefix     = '*'
        SourcePortRange         = '*'
        DestinationAddressPrefix = '*'
        DestinationPortRange    = 22
        Access                  = "Allow"
    }
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig @sshrule

    # Create an inbound network security group rule for port 80
    $webrule =@{
        Name                    = "myNetworkSecurityGroupRuleWWW"
        Protocol                = "Tcp"
        Direction               = "Inbound"
        Priority                = 1001
        SourceAddressPrefix     = '*'
        SourcePortRange         = '*'
        DestinationAddressPrefix = '*'
        DestinationPortRange    = 80
        Access                  = "Allow"
    }
    $nsgRuleWeb = New-AzNetworkSecurityRuleConfig  @webrule

    # Create a network security group
    $netrules =@{
        ResourceGroupName   = $ResourceGroup
        Location            = $location
        Name                = "LinuxWebServers"
    }
    $nsg = New-AzNetworkSecurityGroup @netrules -SecurityRules $nsgRuleSSH,$nsgRuleWeb
} else {
    $nsg = get-AzNetworkSecurityGroup -Name "LinuxWebServers"
}

# Create VM config file
Try{
    # Create a public IP address and specify a DNS name
    $splate =@{
        ResourceGroupName       = $ResourceGroup
        Location                = $location
        AllocationMethod        = 'Static'
        IdleTimeoutInMinutes    = 4
        Name                    = "mypublicdns$(Get-Random)"
    }
    $publicip = New-AzPublicIpAddress @splate

    # Create a virtual network card and associate with public IP address and NSG
    $nic = New-AzNetworkInterface -Name "myNic" -ResourceGroupName $ResourceGroup `
    -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicip.Id -NetworkSecurityGroupId $nsg.Id

    # Define a credential object
    $securePassword = ConvertTo-SecureString 'somepasswordmaybe' -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

    # Create a virtual machine configuration
    $vmConfig = New-AzVMConfig -VMName "myVM" -VMSize "Standard_D1" | 
    Set-AzVMOperatingSystem -Linux -ComputerName "myVM" -Credential $cred -DisablePasswordAuthentication | 
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "18.04-LTS" -Version "latest" | 
    Add-AzVMNetworkInterface -Id $nic.Id

    # Configure the SSH key
    $sshPublicKey = Get-Content ~/.ssh/id_rsa.pub
    Add-AzVMSshPublicKey -VM $vmconfig -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

} catch {
    $_.ErrorDetails.Message
}

# start VM
New-AzVM -ResourceGroupName $ResourceGroup -Location $location -VM $vmConfig
# Get VM IP address
Get-AzVM -ResourceGroupName $ResourceGroup -Name $vmConfig.name | Get-AzPublicIpAddress

# ssh to vm
ssh azureuser@40.78.87.101


# Clean up
Remove-AzResourceGroup -Name $ResourceGroup
Remove-AzResourceGroup -Name NetworkWatcherRG
