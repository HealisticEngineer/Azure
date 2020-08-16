# Create resource pool
$ResourcGroupName = "DemoResourceGroup"
New-AzResourceGroup -Name $ResourcGroupName -Location "West US"

$subcription = (Get-AzSubscription -SubscriptionName "Free Trial").id
$tenantId = (Get-AzContext).Tenant.Id
$ServicePrincipalName = "AutomationService2"

Get-AzContext

# Create resource pool
New-AzResourceGroup -Name $ResourcGroupName -Location "West US"

# create-azure-service-principal-azure  Random password
$sp = New-AzADServicePrincipal -DisplayName $ServicePrincipalName -role "Contributor" -Scope /subscriptions/$subcription/resourceGroups/$resourcgroupname
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret)
$UnsecureSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$sp.ApplicationId

# Use the application ID as the username, and the secret as password
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($sp.ApplicationId, $sp.Secret)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId



# create-azure-service-principal-azure  with password of own making
$credentials = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential -Property @{StartDate=Get-Date; EndDate=Get-Date -Year 2024; Password='StrongPassworld!23'}
$sp = New-AzAdServicePrincipal -DisplayName $ServicePrincipalName -PasswordCredential $credentials



# Creating Certificate
$cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=Automation2" -KeySpec KeyExchange
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

# create-azure-service-principal-azure  with cert
$sp = New-AzADServicePrincipal -DisplayName $ServicePrincipalName -CertValue $keyValue
New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $sp.ApplicationId -Scope /subscriptions/$subcription/resourceGroups/$resourcgroupname


# create with start and end date
$cert = [System.Convert]::ToBase64String((Get-ChildItem -path cert:\CurrentUser\My).where({$_.subject -eq "CN=Automation2"}).GetRawCertData())
$credentials = New-Object Microsoft.Azure.Commands.ActiveDirectory.PSADKeyCredential -Property @{StartDate=Get-Date; EndDate=Get-Date -Year 2024; KeyId=New-Guid; CertValue=$cert}
$sp = New-AzADServicePrincipal -DisplayName $ServicePrincipalName -KeyCredential $credentials


# login using a certificate
$cert = (Get-ChildItem -path cert:\CurrentUser\My).where({$_.subject -eq "CN=Automation2"}).Thumbprint
Connect-AzAccount -ServicePrincipal -Tenant $tenantId -CertificateThumbprint $cert -ApplicationId $sp.ApplicationId
