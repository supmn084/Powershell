Function menu
{
<#
    .SYNOPSIS
     Generate a small "DOS-like" menu.
    .DESCRIPTION
      Allows you to pick  a menuitem using up and down arrows, select by pressing ENTER
    .PARAMETER
        e.g. Specify the requested parameter, if not specified this will be prompted
    .EXAMPLE
        C:\> $Options = "Option1", "Option2", "Option3", "Option4", "Option5"
        C:\> $selection = Menu $Options "Please select an Option?"
 
        ****************************
        * Please select an Option? *
        ****************************
 
        Option1
        Option2
        Option3
        Option4
        Option5
 
        write-host $selection
        Option1
 
#>
    param ([array]$menuItems, $menuTitle = "MENU", [switch]$quit)
    $vkeycode = 0
    $pos = 0
    If ($quit){$menuItems += "Quit"}
    DrawMenu $menuItems $pos $menuTitle
    While ($vkeycode -ne 13) {
        $press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")
        $vkeycode = $press.virtualkeycode
        Write-host "$($press.character)" -NoNewLine
        If ($vkeycode -eq 38) {$pos--}
        If ($vkeycode -eq 40) {$pos++}
        if ($pos -lt 0) {$pos = 0}
        if ($pos -ge $menuItems.length) {$pos = $menuItems.length -1}
        DrawMenu $menuItems $pos $menuTitl
    }
    If ($($menuItems[$pos]) -eq 'Quit'){return}
    Else
    {Write-Output $($menuItems[$pos])}
}
 
function DrawMenu {
    ## supportfunction to the Menu function above
    param ($menuItems, $menuPosition, $menutitle)
    $fcolor = $host.UI.RawUI.ForegroundColor
    $bcolor = $host.UI.RawUI.BackgroundColor
    $l = $menuItems.length + 1
    cls
    $menuwidth = $menutitle.length + 4
    Write-Host "`t" -NoNewLine
    Write-Host ("#" * $menuwidth) -fore $fcolor -back $bcolor
    Write-Host "`t" -NoNewLine
    Write-Host "# $menutitle #" -fore $fcolor -back $bcolor
    Write-Host "`t" -NoNewLine
    Write-Host ("#" * $menuwidth) -fore $fcolor -back $bcolor
    Write-Host ""
    Write-debug "L: $l MenuItems: $menuItems MenuPosition: $menuposition"
    for ($i = 0; $i -le $l;$i++) {
        Write-Host "`t" -NoNewLine
        if ($i -eq $menuPosition) {
            Write-Host "$($menuItems[$i])" -fore $bcolor -back $fcolor
        } else {
            Write-Host "$($menuItems[$i])" -fore $fcolor -back $bcolor
        }
    }
}

