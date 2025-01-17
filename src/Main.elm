port module Main exposing (main)

import AppTypes exposing (Model, Msg(..), Output(..))
import Browser
import Browser.Dom as Dom
import Browser.Events as BE
import Components.Container
import Components.Prompt
import Element as E
import Element.Font as EF
import Html as H
import Json.Decode as Decode
import CommandParser exposing (parse)
import Task


port sendKeyPress : String -> Cmd msg


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { command = "", output = Nothing }
    , Task.attempt (\_ -> NoOp) (Dom.focus "prompt")
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CommandChanged content ->
            ( { model | command = content }, Cmd.none )

        FocusInput ->
            ( model
            , Task.attempt (\_ -> NoOp) (Dom.focus "prompt")
            )

        KeyPress content ->
            case content of
                "Enter" -> (parse model.command model, Cmd.none)
                _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    let
        keyDecoder : Decode.Decoder Msg
        keyDecoder =
            Decode.map KeyPress (Decode.field "key" Decode.string)
    in
    BE.onKeyDown keyDecoder


view : Model -> H.Html Msg
view model =
    Components.Container.view
        [ Components.Prompt.view model
        , case model.output of
            Just (Text output) ->
                E.el [ EF.color (E.rgb 255 255 255) ] (E.text output)

            Just (Element el) -> el

            Nothing ->
                E.none
        ]
