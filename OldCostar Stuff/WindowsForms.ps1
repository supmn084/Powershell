
function do_exit {
     $form.close()
}

function ServicesGrid	{

[void][reflection.assembly]::LoadWithPartialName("System.Windows.Forms")
[void][reflection.assembly]::LoadWithPartialName("System.Drawing")

$form = new-object System.Windows.Forms.Form
$form.Size = new-object System.Drawing.Size 400,500
$Form.Text = "PowerShell TFM"

$DataGridView = new-object System.windows.forms.DataGridView

$array= new-object System.Collections.ArrayList

$data=@(get-service | write-output)
$array.AddRange($data)
$DataGridView.DataSource = $array
$DataGridView.Dock = [System.Windows.Forms.DockStyle]::Fill
$DataGridView.AllowUsertoResizeColumns=$True

$form.Controls.Add($DataGridView)
$form.topmost = $True
$form.showdialog()


}

function HelloForm	{
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$Form = New-Object System.Windows.Forms.Form

#default form size is 300x300 pixels
$Form.width=250
$form.height=200

$Label=new-object System.Windows.Forms.Label
$Label.Text="Hello World"
$Label.visible=$true

$Form.Text = "PowerShell TFM"

$Button = New-Object System.Windows.Forms.Button
$Button.Text = "OK"
#set button vertical button position
$Button.Top=$Form.Height*.50
#default button width is 75
#Center button horizontally
$Button.left=($Form.Width*.50)-75/2
$Button.Add_Click({$Form.Close()})

$Form.Controls.Add($Button)
$Form.Controls.Add($Label)
$Form.ShowDialog()
}


#
#	Main Body
#

ServicesGrid