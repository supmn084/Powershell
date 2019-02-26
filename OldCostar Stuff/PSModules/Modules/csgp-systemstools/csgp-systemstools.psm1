# Function to remove all empty directories under the given path.
# If -DeletePathIfEmpty is provided the given Path directory will also be deleted if it is empty.
# If -OnlyDeleteDirectoriesCreatedBeforeDate is provided, empty folders will only be deleted if they were created before the given date.
# If -OnlyDeleteDirectoriesNotModifiedAfterDate is provided, empty folders will only be deleted if they have not been written to after the given date.
function Remove-EmptyDirectories
{
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$true)]
		[ValidateScript({ Test-Path $_ })]
		[string]$Path,
		[switch]$DeletePathIfEmpty,
		[DateTime]$OnlyDeleteDirectoriesCreatedBeforeDate = [DateTime]::MaxValue,
		[DateTime]$OnlyDeleteDirectoriesNotModifiedAfterDate = [DateTime]::MaxValue
	)
	
	Get-ChildItem -Path $Path -Recurse -Force -Directory | Where-Object { (Get-ChildItem -Path $_.FullName -Recurse -Force -File) -eq $null } |
	Where-Object { $_.CreationTime -lt $OnlyDeleteDirectoriesCreatedBeforeDate -and $_.LastWriteTime -lt $OnlyDeleteDirectoriesNotModifiedAfterDate } |
	Remove-Item -Force -Recurse
	
	# If we should delete the given path when it is empty, and it is a directory, and it is empty, and it meets the date requirements, then delete it.
	if ($DeletePathIfEmpty -and (Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -Force) -eq $null -and
	((Get-Item $Path).CreationTime -lt $OnlyDeleteDirectoriesCreatedBeforeDate) -and ((Get-Item $Path).LastWriteTime -lt $OnlyDeleteDirectoriesNotModifiedAfterDate))
	{ Remove-Item -Path $Path -Force }
}

# Function to remove all files in the given Path that were created before the given date, as well as any empty directories that may be left behind.
function Remove-FilesCreatedBeforeDate
{
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path $_ })]
		[string]$Path,
		[parameter(Mandatory = $true)]
		[DateTime]$DateTime,
		[switch]$DeletePathIfEmpty)
	
	Get-ChildItem -Path $Path -Recurse -Force -File | Where-Object { $_.CreationTime -lt $DateTime } | Remove-Item -Force
	Remove-EmptyDirectories -Path $Path -DeletePathIfEmpty:$DeletePathIfEmpty -OnlyDeleteDirectoriesCreatedBeforeDate $DateTime
}

# Function to remove all files in the given Path that have not been modified after the given date, as well as any empty directories that may be left behind.
function Remove-FilesNotModifiedAfterDate
{
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path $_ })]
		[string]$Path,
		[parameter(Mandatory = $true)]
		[DateTime]$DateTime,
		[switch]$DeletePathIfEmpty)
	
	Get-ChildItem -Path $Path -Recurse -Force -File | Where-Object { $_.LastWriteTime -lt $DateTime } | Remove-Item -Force
	Remove-EmptyDirectories -Path $Path -DeletePathIfEmpty:$DeletePathIfEmpty -OnlyDeleteDirectoriesNotModifiedAfterDate $DateTime
}