<#
    Script: HTML_Uptime_Report.ps1
    Author: jvierra - modified from Ed Wilson (msft) 
    Date: 08/12/2012
    Keywords: Scripting Techniques, Web Pages and HTAs
    comments: added freespace to the script 
    08-12-2012 - jrv - Modifications for demonstration purposes to Ed's script.
                       Altered the way the style is applied
                     - added XML function to colorize rows.
                       
#>
Param(
    [string]$title='Uptime Report', # added for title
    [string]$path='c:\temp\RedGreenUpTime.html',
    [string[]]$servers = @($env:computername,'blah',$env:computername)
)

# function to use XML DOM to find and add class to rows.
function Set-HtmlRowColor{
    param(
        [string]$html,
        [int]$column=0,
        [string]$matchtext='DOWN',
        [string]$class1='down',
        [string]$class2='up'
    )
    $xhtml=[xml]$html
    $rows=$xhtml.SelectNodes('//tr/td/..')
    $rows|%{
        Write-Host "All rows found" -ForegroundColor green
        $attr=$xhtml.CreateAttribute('class')
        $attr.Value=$class2
        [void]$_.Attributes.Append($attr)
    }
    $rows=$xhtml.SelectNodes("//tr/td[text()='$matchtext']/..")
    $rows|%{
        Write-Host "Node found" -ForegroundColor green
        $_.class=$class1
    }
    $xhtml
}

Function Get-UpTime{ 
    Param ([string[]]$servers)
    Foreach ($s in $servers){ 
        if(Test-Connection -cn $s -Quiet -BufferSize 16 -Count 1){
            $os=Get-WmiObject -class win32_OperatingSystem -cn $s
            New-Object psobject -Property @{computer=$s; 
                uptime = (get-date) - $os.converttodatetime($os.lastbootuptime)
            }
        }else{
            New-Object psobject -Property @{computer=$s; uptime = "DOWN"}
        }
    }
 }


# Entry Point ***
#### - jrv style sheet - added classes and reformat
#### - jrv - add type="text/css"
$head=@'
    <title>Uptime Report</title>
    <style type="text/css">
    /*<![CDATA[*/
        body{
            background-color:AntiqueWhite;
        }
        table{
            border-width: 1px;
            border-style: solid;
            border-color: Black;
            border-collapse: collapse;
        }
        th{
            border-width: 1px;
            padding: 0px;
            border-style: solid;
            border-color: black;
            background-color:DarkSalmon;
            width: 200px;
            font-weight: bolder;
            text-align: left;
        }

        /* add class targeting down server */
        .down td{
            border-width: 1px;
            padding: 0px;
            border-style: solid;
            border-color: black;
            color: red;
            font-weight: bolder;
        }

        /* add class targeting UP server */
        .up td{
            border-width: 1px;
            padding: 0px;
            border-style: solid;
            border-color: black;
            color: green;
            font-weight: bolder;
        }
    /*]]>*/
    </style>
'@
$precontent=@"
    <h1>Server Uptime Report</h1>
    <h2>The following report was run on $(get-date)</h2>
"@


$uptime = Get-UpTime -servers $servers | ConvertTo-Html -Fragment
$body=Set-HtmlRowColor -html $uptime
ConvertTo-Html -PostContent $body.innerXML -Head $head -PreContent $precontent -Title 'New Report' |
    Out-File $path
Invoke-Item $path

