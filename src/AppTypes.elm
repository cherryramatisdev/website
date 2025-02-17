module AppTypes exposing (..)

import Element exposing (Element)


type Output
    = Text String
    | Texts (List String)
    | Element (Element Msg)


type alias Model =
    { command : String, output : Maybe Output }


type Msg
    = FocusInput
    | KeyPress String
    | CommandChanged String
    | NoOp
