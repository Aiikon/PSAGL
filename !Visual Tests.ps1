Import-Module .\ -Force
Import-Module ..\HtmlReporting
Import-Module ..\UI

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
        New-MsaglNode One -href "https://test1"
        New-MsaglNode Two -href "https://test2"
        New-MsaglNode Three -href "https://test3"
        New-MsaglNode Four
        New-MsaglNode Five
        New-MsaglNode Six -href "https://test6"

        New-MsaglEdge One Two
        New-MsaglEdge Two Three
        New-MsaglEdge Three Four
        New-MsaglEdge Four Five
        New-MsaglEdge Five Six

        New-MsaglEdge Two One
        New-MsaglEdge Two Four
        New-MsaglEdge Three Six
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

} | Out-HtmlFile