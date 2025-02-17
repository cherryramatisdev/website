module CommandOutputMessages exposing (..)

import AppTypes exposing (Msg)
import Element as E
import Element.Font as EF
import Element.Region exposing (description)


help : List String
help =
    [ "## Welcome to my portfolio honey! Here's the possible commands you can run:"
    , "- help : To show this exact message"
    , "- whoami : To show a brief description about me :)"
    , "- projects : To view the projects i like the most (this website included) and a link for my github where you can find more"
    , "- articles : To view the articles i like the most and a link to my dev.to where you can find more"
    , "- contact : To view multiple ways you can easily contact me"
    ]


whoami : E.Element Msg
whoami =
    let
        src : String
        src =
            "/website/img/me.png"

        -- TODO: Improve this description message
        description : String
        description =
            "A cartoon pixelated"

        aboutMe : List String
        aboutMe =
            [ "Name: Cherry Ramatis", "Job: Web Developer @ iFood", "Languages that I like: Elm, Ruby, Elixir, Go, Rust" ]
    in
    E.row [ E.spacing 10 ]
        [ E.image [ E.width (E.fill |> E.maximum 300), E.height (E.fill |> E.maximum 300) ] { src = src, description = description }
        , E.column [ E.alignTop ] (List.map (\content -> E.el [ EF.color (E.rgb 255 255 255) ] (E.text content)) aboutMe)
        ]


project : E.Element Msg
project =
    E.column [] [ E.text "teste" ]
