module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Url

import View
import Model exposing (Route(..))
import Message exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)


main : Program () Model.Model Msg
main  =
    Browser.application
        { init = init
        , view = View.view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }



init : flags -> Url.Url -> Nav.Key -> ( Model.Model, Cmd Msg )
init flags url key =
    ( Model.initModel url key, Cmd.none )


update : Msg -> Model.Model -> ( Model.Model, Cmd Msg )
update msg model =
    case msg of
        Msg1 ->
            ( model, Cmd.none )

        Msg2 ->
            ( model, Cmd.none )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )


subscriptions : Model.Model -> Sub Msg
subscriptions model =
    Sub.none
