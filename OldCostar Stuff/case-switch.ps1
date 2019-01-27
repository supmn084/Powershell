cls
. h:\dev\powershell\cli_menu2.ps1

$ms = @{}
$ipSpaceByPortgroup = @{}

#
# VM cluster selection
#
$m_vmClusters = Get-cluster
$clusterSelection = Menu $m_vmClusters "Please select an Option?"
$mS.Add('clusterSelection',$clusterSelection)

#
# Select portgroup
#
$m_vmPortGroups = get-cluster -Name $clusterSelection | get-vmhost | select -first 1 | Get-VirtualPortGroup
$vmPortGroupSelection = menu $m_vmPortGroups "Please select an Option?"
$mS.Add('vmPortGroupSelection',$vmPortGroupSelection)

function get-ipSpaceByPortgroup   {
	#
	# Reston IP space
	#
	if ( (Get-Folder Reston | Get-cluster | % {$_.name}) -like $ms.clusterSelection)	{
		switch ($ms.vmPortGroupSelection)	{
			# Network definition
			usdc-lan-dev-app1 
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '172.16.201.1';
									'ipinfo_dns' = '172.16.3.136,172.16.3.137';
								}
				} # end definition
			
			# Network definition
			usdc-lan-dev-web1 
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '172.16.200.1';
									'ipinfo_dns' = '172.16.3.136,172.16.3.137';
								}
				} # end definition
			
			# Network definition
			usdc-lan-tst-app1 
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '172.16.204.1';
									'ipinfo_dns' = '172.16.3.136,172.16.3.137';
								}
				} # end definition
			
			# Network definition
			usdc-dmz-sql 
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '172.16.43.1';
									'ipinfo_dns' = '65.222.181.40,65.222.181.41';
								}
				} # end definition
			
			# Network definition
			usdc-dmz-webapp 
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '172.16.44.1';
									'ipinfo_dns' = '65.222.181.40,65.222.181.41';
								}
				} # end definition
				
			# Network definition
			proddmz1 
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.224.0';
									'ipinfo_gateway' = '65.222.180.62';
									'ipinfo_dns' = '65.222.181.40,65.222.181.41';
								}
				} # end definition
			
			# Network definition
			proddmz0
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '65.222.181.1';
									'ipinfo_dns' = '65.222.181.40,65.222.181.41';
								}
				} # end definition
				
			# Network definition
			corp0
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.252.0';
									'ipinfo_gateway' = '172.16.3.2';
									'ipinfo_dns' = '172.16.3.136,172.16.3.137';
								}
				} # end definition
				
			default { $ipInfo = @{"no selection" = 'empty'} }
		}
		$ipInfo
	} elseif ( (Get-Folder Vienna | Get-cluster | % {$_.name}) -like $ms.clusterSelection)	{
	#
	# Vienna IP Space
	#
		switch ($ms.vmPortGroupSelection)	{
			
			# Network definition
			usvi-dmz-webapp
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '172.16.46.1';
									'ipinfo_dns' = '65.210.23.177,65.210.23.184';
								}
				} # end definition
			
			# Network definition
			usvi-dmz-sql
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.0';
									'ipinfo_gateway' = '172.16.45.1';
									'ipinfo_dns' = '65.210.23.177,65.210.23.184';
								}
				} # end definition
			
			# Network definition
			corp0
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.252.0';
									'ipinfo_gateway' = '172.16.48.1';
									'ipinfo_dns' = '172.16.48.20,172.16.48.23';
								}
				} # end definition
			
			# Network definition
			proddmz0
				{ 
					$ipInfo = @{ 	'ipinfo_portgroup' = $ms.vmPortGroupSelection;
									'ipinfo_netmask' = '255.255.255.128';
									'ipinfo_gateway' = '65.210.23.254';
									'ipinfo_dns' = '65.210.23.177,65.210.23.184';
								}
				} # end definition
				
			default { $ipInfo = @{"no selection" = 'empty'} }
		}
		$ipInfo
	} 

} # end func

$ipSpaceByPortgroup = get-ipSpaceByPortgroup 