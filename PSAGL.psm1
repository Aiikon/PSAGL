try
{
    Add-Type -Path "$PSScriptRoot\Microsoft.GLEE.dll" -ErrorAction Stop
}
catch
{
    Write-Error "Microsoft.GLEE.dll must be present in the module directory."
    return
}

Function New-MsaglGraph
{
    Param
    (
        [Parameter(Mandatory=$true)] [ValidateSet('ImgTag', 'Control')] [string] $As,
        [Parameter(Mandatory=$true)] [ScriptBlock] $Definition
    )
    End
    {
        $defList = $Definition.Invoke()
        $nodeList = $defList | Where-Object Type -eq Node
        $edgeList = $defList | Where-Object Type -eq Edge

        $graph = New-Object Microsoft.Glee.GleeGraph
        $nodeDict = @{}
        $nodeToControl = @{}

        $maxSize = New-Object System.Windows.Size ([double]::MaxValue), ([double]::MaxValue)

        foreach ($node in $nodeList)
        {
            $textblock = New-UITextBlock -Text $node.Label -Margin 4,2,4,2
            $control = New-UIBorder -Align TopLeft -BorderBrush Black -BorderThickness 1 -CornerRadius 2 -Child $textblock -Background White
            $control.Measure($maxSize)
            $point = New-Object Microsoft.Glee.Splines.Point 0,0
            $box = [Microsoft.Glee.Splines.CurveFactory]::CreateBox($control.DesiredSize.Width, $control.DesiredSize.Height, $point)
            $msaglNode = New-Object Microsoft.Glee.Node $node.Id, $box
            $graph.AddNode($msaglNode)
            $nodeDict[$node.Id] = $msaglNode
            $nodeToControl[$msaglNode] = $control
        }

        foreach ($edge in $edgeList)
        {
            $msaglEdge = New-Object Microsoft.Glee.Edge $nodeDict[$edge.ParentId], $nodeDict[$edge.ChildId]
            $graph.Edges.Add($msaglEdge)
        }

        $graph.CalculateLayout()

        $outputControl = New-UIGrid -Align TopLeft {
            $graph.Edges | ForEach-Object {
                $polyLineList = $_.UnderlyingPolyline | Select-Object
                $points = foreach ($polyLine in $polyLineList)
                {
                    $graph.Right - $polyLine.X
                    $graph.Top - $polyLine.Y
                }
                New-UIPolyline -Points $points -StrokeThickness 1 -Stroke Black
            }
            $nodeDict.Values | ForEach-Object {
                $y = $graph.Top - $_.BBox.Top
                $x = $graph.Right - $_.BBox.Right
                $control = $nodeToControl[$_]
                $control.Margin = New-Object System.Windows.Thickness $x, $y, 0, 0
                $control
            }
        }

        if ($As -eq 'Control') { return $outputControl }

        $outputControl.Measure($maxSize)
        $outputControl.Width = $outputControl.DesiredSize.Width
        $outputControl.Height = $outputControl.DesiredSize.Height
        $finalSize = New-Object System.Windows.Size $outputControl.Width, $outputControl.Height
        $outputControl.Arrange((New-Object System.Windows.Rect $finalSize))
        $outputControl.UpdateLayout()

        $renderer = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($outputControl.Width, $outputControl.Height, 96d, 96d, [System.Windows.Media.PixelFormats]::Default)
        $renderer.Render($outputControl)

        $pngEncoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $pngEncoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($renderer))

        $memStream = New-Object System.IO.MemoryStream
        $pngEncoder.Save($memStream)
        $memStream.Close()

        $bytes = $memStream.ToArray()
        $base64 = [Convert]::ToBase64String($bytes)
        "<img src='data:image/png;base64,$base64' />"
    }
}

Function New-MsaglNode
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)] [string] $Label,
        [Parameter()] [string] $Id
    )
    End
    {
        if (!$Id) { $Id = $Label }
        $node = [ordered]@{}
        $node.Type = 'Node'
        $node.Label = $Label
        $node.Id = $Id
        [pscustomobject]$node
    }
}

Function New-MsaglEdge
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)] [string] $ParentId,
        [Parameter(Mandatory=$true, Position=1)] [string] $ChildId
    )
    End
    {
        $edge = [ordered]@{}
        $edge.Type = 'Edge'
        $edge.ParentId = $ParentId
        $edge.ChildId = $ChildId
        [pscustomobject]$edge
    }
}


<# Sample
Show-UIWindow {
     New-MsaglGraph -As Control -Definition {
        New-MsaglNode One
        New-MsaglNode Two
        New-MsaglNode Three
        New-MsaglNode Four
        New-MsaglNode Five
        New-MsaglNode Six

        New-MsaglEdge One Two
        New-MsaglEdge Two Three
        New-MsaglEdge Three Four
        New-MsaglEdge Four Five
        New-MsaglEdge Five Six

        New-MsaglEdge Two One
        New-MsaglEdge Two Four
        New-MsaglEdge Three Six
     }
}
#>