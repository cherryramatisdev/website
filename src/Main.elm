module Main exposing (main)

import Browser
import Element as E
import Element.Background as B
import Element.Border as Border
import Element.Font as F
import Element.Input as I
import Html exposing (Html)
import Html.Attributes


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , view = view
        , update = update
        }


type alias Model =
    { command : String }


init : Model
init =
    { command = "" }


type Msg
    = CommandChanged String


update : Msg -> Model -> Model
update msg model =
    case msg of
        CommandChanged text ->
            { model | command = String.replace "$ " "" text }


view : Model -> Html.Html Msg
view model =
    layout_el
        [ E.row [ E.htmlAttribute (Html.Attributes.style "position" "relative") ]
            [ E.el [ F.color (E.rgb 255 255 255) ]
                (I.text [ B.color (E.rgba 0 0 0 0), Border.width 0 ]
                    { onChange = CommandChanged
                    , text = "$ " ++ model.command
                    , placeholder = Just (I.placeholder [] (E.text "hello world"))
                    , label = I.labelAbove [] (E.text "hello world")
                    }
                )
            , E.html (Html.div [ Html.Attributes.class "command-cursor" ] [])
            ]
        ]
        |> E.layout []


layout_el : List (E.Element msg) -> E.Element msg
layout_el els =
    E.column
        [ B.color (E.rgb 0 0 0)
        , E.width E.fill
        , E.height E.fill
        , E.alignTop
        , E.spacing 30
        ]
        els
