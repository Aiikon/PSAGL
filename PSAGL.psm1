﻿try
{
    Add-Type -Path "$PSScriptRoot\Microsoft.GLEE.dll" -ErrorAction Stop
}
catch
{
    Write-Error "Microsoft.GLEE.dll must be present in the module directory."
    return
}

# This was taken Rod Stephens's example:
# http://csharphelper.com/blog/2019/04/draw-a-smooth-curve-in-wpf-and-c/
Add-Type -ReferencedAssemblies PresentationCore, PresentationFramework, WindowsBase, System.Xaml @"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Rhodium.PSAGL
{
    public static class BezierHelper
    {

        // Make an array containing Bezier curve points and control points.
        private static Point[] MakeCurvePoints(Point[] points, double tension)
        {
            if (points.Length < 2) return null;
            double control_scale = tension / 0.5 * 0.175;

            // Make a list containing the points and
            // appropriate control points.
            List<Point> result_points = new List<Point>();
            result_points.Add(points[0]);

            for (int i = 0; i < points.Length - 1; i++)
            {
                // Get the point and its neighbors.
                Point pt_before = points[Math.Max(i - 1, 0)];
                Point pt = points[i];
                Point pt_after = points[i + 1];
                Point pt_after2 = points[Math.Min(i + 2, points.Length - 1)];

                double dx1 = pt_after.X - pt_before.X;
                double dy1 = pt_after.Y - pt_before.Y;

                Point p1 = points[i];
                Point p4 = pt_after;

                double dx = pt_after.X - pt_before.X;
                double dy = pt_after.Y - pt_before.Y;
                Point p2 = new Point(
                    pt.X + control_scale * dx,
                    pt.Y + control_scale * dy);

                dx = pt_after2.X - pt.X;
                dy = pt_after2.Y - pt.Y;
                Point p3 = new Point(
                    pt_after.X - control_scale * dx,
                    pt_after.Y - control_scale * dy);

                // Save points p2, p3, and p4.
                result_points.Add(p2);
                result_points.Add(p3);
                result_points.Add(p4);
            }

            // Return the points.
            return result_points.ToArray();
        }

        // Make a Path holding a series of Bezier curves.
        // The points parameter includes the points to visit
        // and the control points.
        private static Path MakeBezierPath(Point[] points)
        {
            // Create a Path to hold the geometry.
            Path path = new Path();

            // Add a PathGeometry.
            PathGeometry path_geometry = new PathGeometry();
            path.Data = path_geometry;

            // Create a PathFigure.
            PathFigure path_figure = new PathFigure();
            path_geometry.Figures.Add(path_figure);

            // Start at the first point.
            path_figure.StartPoint = points[0];

            // Create a PathSegmentCollection.
            PathSegmentCollection path_segment_collection =
                new PathSegmentCollection();
            path_figure.Segments = path_segment_collection;

            // Add the rest of the points to a PointCollection.
            PointCollection point_collection =
                new PointCollection(points.Length - 1);
            for (int i = 1; i < points.Length; i++)
                point_collection.Add(points[i]);

            // Make a PolyBezierSegment from the points.
            PolyBezierSegment bezier_segment = new PolyBezierSegment();
            bezier_segment.Points = point_collection;

            // Add the PolyBezierSegment to othe segment collection.
            path_segment_collection.Add(bezier_segment);

            return path;
        }

        // Make a Bezier curve connecting these points.
        public static Path MakeCurve(Point[] points, double tension)
        {
            if (points.Length < 2) return null;
            Point[] result_points = MakeCurvePoints(points, tension);

            // Use the points to create the path.
            return MakeBezierPath(result_points.ToArray());
        }
    }
}
"@

Function New-MsaglGraph
{
    Param
    (
        [Parameter(Mandatory=$true)] [ValidateSet('ImgTag', 'Control')] [string] $As,
        [Parameter(Mandatory=$true)] [ScriptBlock] $Definition,
        [Parameter()] [string] $ImageMapName,
        [Parameter()] [hashtable] $ControlHrefs
    )
    End
    {
        $defList = $Definition.Invoke()
        $nodeList = $defList | Where-Object Type -eq Node
        $edgeList = $defList | Where-Object Type -eq Edge

        $graph = [Microsoft.Glee.GleeGraph]::new()
        $nodeDict = @{}
        if (!$ControlHrefs) { $ControlHrefs = @{} }
        $nodeToControl = @{}

        $maxSize = [System.Windows.Size]::new([double]::MaxValue, [double]::MaxValue)

        foreach ($node in $nodeList)
        {
            if ($node.Control) { $control = $node.Control }
            else
            {
                $textblock = New-UITextBlock -Text $node.Label -Margin 4,2,4,2 -FontSize $node.FontSize
                $control = New-UIBorder -Align TopLeft -BorderBrush Black -BorderThickness 1 -CornerRadius 2 -Child $textblock -Background $node.Background
            }
            if ($node.Href) { $ControlHrefs[$control] = $node.Href }
            $control.Measure($maxSize)
            $point = [Microsoft.Glee.Splines.Point]::new(0,0)
            $box = [Microsoft.Glee.Splines.CurveFactory]::CreateBox($control.DesiredSize.Width, $control.DesiredSize.Height, $point)
            $msaglNode = [Microsoft.Glee.Node]::new($node.Id, $box)
            $graph.AddNode($msaglNode)
            $nodeDict[$node.Id] = $msaglNode
            $nodeToControl[$msaglNode] = $control
        }

        foreach ($edge in $edgeList)
        {
            $msaglEdge = [Microsoft.Glee.Edge]::new($nodeDict[$edge.ParentId], $nodeDict[$edge.ChildId])
            $msaglEdge.UserData = $edge
            $msaglEdge.ArrowHeadAtTarget = $edge.ArrowAt -in 'Child', 'Both'
            $msaglEdge.ArrowHeadAtSource = $edge.ArrowAt -in 'Parent', 'Both'
            $graph.Edges.Add($msaglEdge)
        }

        $graph.CalculateLayout()

        $outputControl = New-UIGrid -Margin 0,0,2,2 -Align TopLeft {
            $graph.Edges | ForEach-Object {
                $polyLineList = $_.UnderlyingPolyline | Select-Object -Skip ([int]$_.ArrowHeadAtSource) | Select-Object -SkipLast ([int]$_.ArrowHeadAtTarget)
                $points = @(
                    if ($_.ArrowHeadAtSource)
                    {
                        $graph.Right - $_.ArrowHeadAtSourcePosition.X
                        $graph.Top - $_.ArrowHeadAtSourcePosition.Y
                    }
                    foreach ($polyLine in $polyLineList)
                    {
                        $graph.Right - $polyLine.X
                        $graph.Top - $polyLine.Y
                    }
                    if ($_.ArrowHeadAtTarget)
                    {
                        $graph.Right - $_.ArrowHeadAtTargetPosition.X
                        $graph.Top - $_.ArrowHeadAtTargetPosition.Y
                    }
                )

                $pointList = for ($i = 0; $i -lt $points.Count; $i+=2)
                {
                    [System.Windows.Point]::new($points[$i], $points[$i+1])
                }

                $path = [Rhodium.PSAGL.BezierHelper]::MakeCurve($pointList, 0.2)
                $path.StrokeThickness = 1;
                $path.Stroke = $_.UserData.Stroke
                if ($_.UserData.StrokeDashArray) { $path.StrokeDashArray = $_.UserData.StrokeDashArray }
                $path

                $arrowPointList = @(
                    if ($_.ArrowHeadAtSource) { [pscustomobject]@{From=$pointList[1]; To=$pointList[0]} }
                    if ($_.ArrowHeadAtTarget) { [pscustomobject]@{From=$pointList[-2]; To=$pointList[-1]} }
                )

                foreach ($arrowPoint in $arrowPointList)
                {
                    # Matrix rotation example taken from Charles Petzold
                    # http://www.charlespetzold.com/blog/2007/04/191200.html
                    $matrix = [System.Windows.Media.Matrix]::Identity
                    $vector = [System.Windows.Vector]($arrowPoint.From - $arrowPoint.To)
                    $vector.Normalize()
                    $vector *= 10

                    $matrix.Rotate(60/2)
                    $point1 = $arrowPoint.To + $vector * $matrix

                    $matrix.Rotate(-60)
                    $point2 = $arrowPoint.To + $vector * $matrix

                    $polygonPointList = @($point1.X, $point1.Y, $arrowPoint.To.X, $arrowPoint.To.Y, $point2.X, $point2.Y)

                    $line = New-UIPolygon -Points $polygonPointList -Fill Black
                    $line
                }
            }

            $nodeDict.Values | ForEach-Object {
                $y = $graph.Top - $_.BBox.Top
                $x = $graph.Right - $_.BBox.Right
                $control = $nodeToControl[$_]
                $control.Margin = [System.Windows.Thickness]::new($x, $y, 0, 0)
                $control
            }

        }

        if ($As -eq 'Control') { return $outputControl }

        $outputControl.Measure($maxSize)
        $outputControl.Width = $outputControl.DesiredSize.Width
        $outputControl.Height = $outputControl.DesiredSize.Height
        $finalSize = [System.Windows.Size]::new($outputControl.Width, $outputControl.Height)
        $outputControl.Arrange([System.Windows.Rect]::new($finalSize))
        $outputControl.UpdateLayout()

        $mapAttr = ''
        $mapHtml = if ($ControlHrefs.Keys.Count)
        {
            if (!$ImageMapName) { $ImageMapName = [Guid]::NewGuid().ToString('n') }
            $mapAttr = " usemap='#$ImageMapName'"
            "<map name='$ImageMapName'>"
            foreach ($control in $ControlHrefs.Keys)
            {
                $pos = $control.TranslatePoint([System.Windows.Point]::new(0,0), $outputControl)
                $coords = @(
                    $pos.X
                    $pos.Y
                    $pos.X + $control.ActualWidth
                    $pos.Y + $control.ActualHeight
                ) -join ','
                "<area shape='rect' coords='$coords' href='$($ControlHrefs[$control])' />"
            }
            "</map>"
        }
        
        $mapHtml = $mapHtml -join ''

        $renderer = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($outputControl.Width, $outputControl.Height, 96d, 96d, [System.Windows.Media.PixelFormats]::Default)
        $renderer.Render($outputControl)

        $pngEncoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
        $pngEncoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($renderer))

        $memStream = [System.IO.MemoryStream]::new()
        $pngEncoder.Save($memStream)
        $memStream.Close()

        $bytes = $memStream.ToArray()
        $base64 = [Convert]::ToBase64String($bytes)
        "<img src='data:image/png;base64,$base64'$mapAttr />$mapHtml"
    }
}

Function New-MsaglNode
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)] [string] $Id,
        [Parameter(Position=1)] [string] $Label,
        [Parameter()] [object] $Control,
        [Parameter()] [string] $Href,
        [Parameter()] [object] $Background = 'White',
        [Parameter()] [double] $FontSize = 12
    )
    End
    {
        if (!$Label) { $Label = $Id }
        $byte = try { [byte[]]$Background } catch { }
        if ($byte -and $byte.Length -eq 3) { $Background = New-UISolidColorBrush -RGB $byte }
        $node = [ordered]@{}
        $node.Type = 'Node'
        $node.Id = $Id
        $node.Label = $Label
        $node.Control = $Control
        $node.Href = $Href
        $node.Background = $Background
        $node.FontSize = $FontSize
        [pscustomobject]$node
    }
}

Function New-MsaglEdge
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)] [string] $ParentId,
        [Parameter(Mandatory=$true, Position=1)] [string] $ChildId,
        [Parameter()] [double[]] $StrokeDashArray,
        [Parameter()] [object] $Stroke = 'Black',
        [Parameter()] [ValidateSet('Child', 'Parent', 'Both', 'None')] [string] $ArrowAt = 'Child'
    )
    End
    {
        $byte = try { [byte[]]$Stroke } catch { }
        if ($byte -and $byte.Length -eq 3) { $Stroke = New-UISolidColorBrush -RGB $byte }
        $edge = [ordered]@{}
        $edge.Type = 'Edge'
        $edge.ParentId = $ParentId
        $edge.ChildId = $ChildId
        $edge.StrokeDashArray = $StrokeDashArray
        $edge.Stroke = $Stroke
        $edge.ArrowAt = $ArrowAt
        [pscustomobject]$edge
    }
}
