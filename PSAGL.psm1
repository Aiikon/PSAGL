try
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
            if ($node.Control) { $control = $node.Control }
            else
            {
                $textblock = New-UITextBlock -Text $node.Label -Margin 4,2,4,2
                $control = New-UIBorder -Align TopLeft -BorderBrush Black -BorderThickness 1 -CornerRadius 2 -Child $textblock -Background White
            }
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

        $outputControl = New-UIGrid -Margin 0,0,2,2 -Align TopLeft {
            $graph.Edges | ForEach-Object {
                $polyLineList = $_.UnderlyingPolyline | Select-Object
                $points = foreach ($polyLine in $polyLineList)
                {
                    $graph.Right - $polyLine.X
                    $graph.Top - $polyLine.Y
                }

                $pointList = for ($i = 0; $i -lt $points.Count; $i+=2)
                {
                    [System.Windows.Point]::new($points[$i], $points[$i+1])
                }

                $path = [Rhodium.PSAGL.BezierHelper]::MakeCurve($pointList, 0.4)
                $path.StrokeThickness = 1;
                $path.Stroke = 'Black'
                $path
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
        [Parameter()] [string] $Id,
        [Parameter()] [object] $Control
    )
    End
    {
        if (!$Id) { $Id = $Label }
        $node = [ordered]@{}
        $node.Type = 'Node'
        $node.Label = $Label
        $node.Id = $Id
        $node.Control = $Control
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