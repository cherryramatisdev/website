module Components.Container exposing (view)

import Element as E
import Element.Background as EB
import Element.Font as EF
import Html exposing (Html)


view : List (E.Element msg) -> Html msg
view children =
    E.layout [] <|
        E.column
            [ E.width E.fill
            , E.height E.fill
            , EB.color (E.rgb 0 0 0)
            , E.padding 20
            , E.centerX
            , E.centerY
            , EF.family [ EF.typeface "VT323" ]
            ]
            children
