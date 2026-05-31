param(
    [string]$OutputFolder = ".",
    [switch]$UseDeviceAuthentication,
    [switch]$SkipUserLicenseDetail
)

$ErrorActionPreference = "Stop"

function Ensure-Module {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Install-Module $Name -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $Name -Force
}

function Get-Prop {
    param($Object, [string[]]$Names)
    foreach ($name in $Names) {
        if ($null -ne $Object.PSObject.Properties[$name]) {
            return $Object.$name
        }
    }
    return $null
}

function Join-Values {
    param($Value)
    if ($null -eq $Value) { return "" }
    if ($Value -is [array]) { return ($Value | ForEach-Object { $_.ToString() }) -join ";" }
    return $Value.ToString()
}

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

Ensure-Module -Name PartnerCenter

Write-Host "Connecting to Partner Center..."
if ($UseDeviceAuthentication) {
    Connect-PartnerCenter -UseDeviceAuthentication | Out-Null
} else {
    Connect-PartnerCenter | Out-Null
}

$customersCsv = Join-Path $OutputFolder "PartnerCenter-Customers.csv"
$skusCsv      = Join-Path $OutputFolder "PartnerCenter-SubscribedSkus.csv"
$usersCsv     = Join-Path $OutputFolder "PartnerCenter-Users.csv"
$userLicCsv   = Join-Path $OutputFolder "PartnerCenter-UserLicenses.csv"
$errorsCsv    = Join-Path $OutputFolder "PartnerCenter-Errors.csv"

$customerRows = New-Object System.Collections.Generic.List[object]
$skuRows      = New-Object System.Collections.Generic.List[object]
$userRows     = New-Object System.Collections.Generic.List[object]
$userLicRows  = New-Object System.Collections.Generic.List[object]
$errorRows    = New-Object System.Collections.Generic.List[object]

Write-Host "Getting Partner Center customers..."
$customers = Get-PartnerCustomer

foreach ($customer in $customers) {
    $customerId = Get-Prop $customer @("CustomerId", "Id", "TenantId")
    $customerName = Get-Prop $customer @("Name", "CompanyProfile.CompanyName", "CompanyName")
    $domain = Get-Prop $customer @("Domain", "DefaultDomain", "DefaultDomainName")

    if ([string]::IsNullOrWhiteSpace($customerName)) { $customerName = $customer.Name }
    if ([string]::IsNullOrWhiteSpace($customerId)) { continue }

    Write-Host "Processing customer: $customerName [$customerId]"

    $customerRows.Add([pscustomobject]@{
        CustomerName = $customerName
        CustomerId   = $customerId
        Domain       = $domain
    })

    try {
        $skus = Get-PartnerCustomerSubscribedSku -CustomerId $customerId -LicenseGroup Group1
        foreach ($sku in $skus) {
            $skuRows.Add([pscustomobject]@{
                CustomerName     = $customerName
                CustomerId       = $customerId
                ProductSkuName   = Get-Prop $sku @("ProductSku.Name", "SkuPartNumber", "Name", "ProductName")
                ProductSkuId     = Get-Prop $sku @("ProductSku.Id", "SkuId", "Id")
                AvailableUnits   = Get-Prop $sku @("AvailableUnits", "AvailableLicenses")
                ActiveUnits      = Get-Prop $sku @("ActiveUnits", "TotalLicenses")
                ConsumedUnits    = Get-Prop $sku @("ConsumedUnits", "AssignedLicenses")
                SuspendedUnits   = Get-Prop $sku @("SuspendedUnits")
                WarningUnits     = Get-Prop $sku @("WarningUnits")
                CapabilityStatus = Get-Prop $sku @("CapabilityStatus", "Status")
                LicenseGroup     = "Group1"
            })
        }
    }
    catch {
        Write-Warning "Failed subscribed SKUs for $customerName [$customerId]: $($_.Exception.Message)"
        $errorRows.Add([pscustomobject]@{
            CustomerName = $customerName
            CustomerId   = $customerId
            Stage        = "SubscribedSkus"
            Error        = $_.Exception.Message
        })
    }

    try {
        $users = Get-PartnerCustomerUser -CustomerId $customerId
        foreach ($user in $users) {
            $userId = Get-Prop $user @("UserId", "Id")
            $upn = Get-Prop $user @("UserPrincipalName", "UserPrincipalName")
            $displayName = Get-Prop $user @("DisplayName", "Name")

            $userRows.Add([pscustomobject]@{
                CustomerName      = $customerName
                CustomerId        = $customerId
                DisplayName       = $displayName
                UserPrincipalName = $upn
                UserId            = $userId
                FirstName         = Get-Prop $user @("FirstName")
                LastName          = Get-Prop $user @("LastName")
                UsageLocation     = Get-Prop $user @("UsageLocation")
                State             = Get-Prop $user @("State")
                IsLicensed        = Get-Prop $user @("IsLicensed")
                UserDomainType    = Get-Prop $user @("UserDomainType")
            })

            if (-not $SkipUserLicenseDetail -and -not [string]::IsNullOrWhiteSpace($userId)) {
                try {
                    $licenses = Get-PartnerCustomerUserLicense -CustomerId $customerId -UserId $userId -LicenseGroup Group1
                    foreach ($lic in $licenses) {
                        $userLicRows.Add([pscustomobject]@{
                            CustomerName      = $customerName
                            CustomerId        = $customerId
                            DisplayName       = $displayName
                            UserPrincipalName = $upn
                            UserId            = $userId
                            ProductSkuName    = Get-Prop $lic @("ProductSku.Name", "SkuPartNumber", "Name", "ProductName")
                            ProductSkuId      = Get-Prop $lic @("ProductSku.Id", "SkuId", "Id")
                            ServicePlans      = Join-Values (Get-Prop $lic @("ServicePlans") )
                            LicenseGroup      = "Group1"
                        })
                    }
                }
                catch {
                    $errorRows.Add([pscustomobject]@{
                        CustomerName = $customerName
                        CustomerId   = $customerId
                        Stage        = "UserLicenses:$upn"
                        Error        = $_.Exception.Message
                    })
                }
            }
        }
    }
    catch {
        Write-Warning "Failed users for $customerName [$customerId]: $($_.Exception.Message)"
        $errorRows.Add([pscustomobject]@{
            CustomerName = $customerName
            CustomerId   = $customerId
            Stage        = "Users"
            Error        = $_.Exception.Message
        })
    }
}

$customerRows | Export-Csv $customersCsv -NoTypeInformation -Encoding UTF8
$skuRows      | Export-Csv $skusCsv      -NoTypeInformation -Encoding UTF8
$userRows     | Export-Csv $usersCsv     -NoTypeInformation -Encoding UTF8
$userLicRows  | Export-Csv $userLicCsv   -NoTypeInformation -Encoding UTF8
$errorRows    | Export-Csv $errorsCsv    -NoTypeInformation -Encoding UTF8

Write-Host "Done."
Write-Host "Customers:      $customersCsv"
Write-Host "Subscribed SKUs: $skusCsv"
Write-Host "Users:          $usersCsv"
Write-Host "User licenses:  $userLicCsv"
Write-Host "Errors:         $errorsCsv"
