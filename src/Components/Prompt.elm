module Components.Prompt exposing (view)

import AppTypes exposing (Model, Msg(..))
import Element as E
import Element.Background as EB
import Element.Border as EBd
import Element.Events as EE
import Element.Font as EF
import Html
import Html.Attributes as HA
import Html.Events as HE


view : Model -> E.Element Msg
view model =
    E.el
        [ E.width E.fill
        , E.spacing 5
        , EBd.width 1
        , EB.color (E.rgba 0 0 0 0)
        , EF.size 20
        , EE.onClick FocusInput
        , E.centerX
        ]
    <|
        E.row [ EF.color (E.rgb 255 255 255) ]
            [ E.el [ E.paddingEach { top = 0, right = 10, bottom = 0, left = 0 } ] (E.text "$")
            , inputField model.command
            , cursor
            ]


textLengthToCssUnit : String -> String
textLengthToCssUnit content =
    String.fromInt (String.length content * 8) ++ "px"


inputField : String -> E.Element Msg
inputField input =
    let
        placeholder =
            "Type help and press Enter"
    in
    E.html
        (Html.input
            [ HE.onInput CommandChanged
            , HA.value input
            , HA.placeholder placeholder
            , HA.style "color" "#fff"
            , HA.id "prompt"
            , HA.style "width"
                (textLengthToCssUnit
                    (if String.isEmpty input then
                        placeholder

                     else
                        input
                    )
                )
            ]
            []
        )


cursor : E.Element Msg
cursor =
    E.el
        [ E.width (E.px 10)
        , E.height (E.px 20)
        , EB.color (E.rgb 0 1 0)
        , E.htmlAttribute (HA.style "animation" "blink 1s infinite")
        , EE.onClick FocusInput
        ]
        E.none
