module CommandParser exposing (..)

import AppTypes exposing (Model, Output(..))
import CommandOutputMessages

parse : String -> Model -> Model
parse cmd model =
    case cmd of
        "help" -> addOutputToCmd (Just (Text CommandOutputMessages.help)) model
        "whoami" -> addOutputToCmd (Just (Element CommandOutputMessages.whoami)) model
        "contact" -> addOutputToCmd (Just (Element CommandOutputMessages.whoami)) model
        "clear" -> addOutputToCmd Nothing model
        _ -> addOutputToCmd (Just (Text "Command not found")) model


addOutputToCmd : Maybe Output -> Model -> Model
addOutputToCmd output model =
    ({ model | output = output, command = ""})
