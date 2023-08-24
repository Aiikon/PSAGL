Import-Module $PSScriptRoot -Force
Import-Module $PSScriptRoot\..\HtmlReporting
Import-Module $PSScriptRoot\..\UI

[void]{
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
}

& {
    Import-HtmlTagFunctions

    h1 "Simple Graph"

    New-MsaglGraph -As ImgTag -Definition {
        New-MsaglNode One -href "https://test1" -FontSize 18 -Background 67,134,216
        New-MsaglNode Two -href "https://test2"
        New-MsaglNode Three -href "https://test3"
        New-MsaglNode Four
        New-MsaglNode Five
        New-MsaglNode Six -href "https://test6" -FontSize 10 -Background Red

        New-MsaglEdge One Two
        New-MsaglEdge Two Three
        New-MsaglEdge Three Four
        New-MsaglEdge Four Five
        New-MsaglEdge Five Six -ArrowAt Both

        New-MsaglEdge Two One
        New-MsaglEdge Two Four
        New-MsaglEdge Three Six -ArrowAt Parent
    }

    h1 "Custom Control Graph"

    $link1 = New-UITextBlock "Clickable 1" -Foreground Blue
    $link2 = New-UITextBlock "Clickable 2" -Foreground Blue

    $linkDict = @{
        $link1 = '/link1'
        $link2 = '/link2'
    }

    New-MsaglGraph -As ImgTag -ControlHrefs $linkDict -Definition {
        New-MsaglNode One -href "/test" -Control (
            New-UIBorder -CornerRadius 2 -Background White -BorderBrush Black -BorderThickness 1 -Align TopLeft @(
                New-UIStackPanel -Margin 2 @(
                    New-UITextBlock -FontWeight Bold "Header"
                    New-UITextBlock "Some long sentence of text..."
                )
            )
        )

        New-MsaglNode Two

        New-MsaglNode Three -Control (
            New-UIBorder -CornerRadius 2 -Background White -BorderBrush Black -BorderThickness 1 -Align TopLeft @(
                New-UIStackPanel -Margin 2 @(
                    New-UITextBlock -FontWeight Bold "Clickable Items"
                    $link1
                    $link2
                )
            )
        )

        New-MsaglNode Four -Href "/triangle" -Control (
            New-UIGrid -Align TopLeft @(
                New-UIPolygon -Fill SkyBlue -Points @(
                    10,110, 60,10, 110,110
                )
                New-UITextBlock "Also Clickable" -TextAlignment Center -Align BottomCenter -Margin 10,0,0,10
            )
        )

        New-MsaglEdge One Two
        New-MsaglEdge Two Three

        New-MsaglEdge One Four
        New-MsaglEdge Two Four
    }

    h1 "Graph Within a Graph"

    New-MsaglGraph -As ImgTag -Definition {

        New-MsaglNode Parent
        New-MsaglNode Child -Control (
            New-UIBorder -CornerRadius 2 -Background White -BorderBrush Black -BorderThickness 1 -Align TopLeft @(
                New-UIGrid @(
                    New-MsaglGraph -As Control -Definition {
                        New-MsaglNode Step1
                        New-MsaglNode Step2
                        New-MsaglNode Step3
                        New-MsaglNode Step4

                        New-MsaglEdge Step1 Step2
                        New-MsaglEdge Step2 Step3
                        New-MsaglEdge Step3 Step4
                        New-MsaglEdge Step2 Step4
                    }
                )
            )
        )
        New-MsaglNode Grandchild

        New-MsaglEdge Parent Child
        New-MsaglEdge Child Grandchild
        New-MsaglEdge Parent Grandchild -StrokeDashArray 2,2 -Stroke (255,0,0)

    }

} | Out-HtmlFile