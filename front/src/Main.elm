port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Url
import Json.Decode as D

import View
import Model exposing (Route(..))
import Message exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Model exposing (sessionDecoder)
import Time
import Task
import Dict
import Model exposing (strToHttpMethod)
import Model exposing (HttpMethod(..))


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


-- PORTS

port sessionReciever : (String -> msg) -> Sub msg



init : flags -> Url.Url -> Nav.Key -> ( Model.Model, Cmd Msg )
init flags url key =
    ( Model.initModel url key, Task.perform GetTimezone Time.here )


update : Msg -> Model.Model -> ( Model.Model, Cmd Msg )
update msg model =
    case msg of
        GetTimezone zone ->
            ({ model | timezone = zone}, Cmd.none)
        RecvSession message ->
            let
                (newSessionList, selectedSession) =
                    case D.decodeString sessionDecoder message of
                        Ok session ->
                            ( session :: model.sessions
                                |> List.take 3000
                            , Model.maybeIncrement model.selectedSession
                            )
                        Err _ ->
                            (model.sessions, model.selectedSession)
            in
            ( { model | sessions = newSessionList, selectedSession = selectedSession }
            , Cmd.none
            )

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
        
        ChangeSelectedSession i ->
            ( { model | selectedSession = Just i}
            , Cmd.none
            )
        
        AddFilter t ->
            let
                filter = model.filter
                filterEditor_ = model.filterEditor
            in
            case t of
                Model.Status ->
                    let
                        (statusFilter, filterEditor) = case String.toInt model.filterEditor.status of
                            Nothing ->
                                (model.filter.status, filterEditor_)  -- TODO: エラー通知
                            Just s ->
                                ( s :: model.filter.status
                                    |> uniqueList
                                , { filterEditor_ | status = "" }
                                )
                    in
                    ( { model | filter = { filter | status = statusFilter }, filterEditor = filterEditor }
                    , Cmd.none
                    )
                Model.Method ->
                    let
                        (modelFilter, filterEditor) = case strToHttpMethod model.filterEditor.method of
                            Other _ ->
                                (model.filter.method, filterEditor_)  -- TODO: エラー通知
                            x ->
                                ( x :: model.filter.method
                                    |> uniqueList
                                , { filterEditor_ | method = "" }
                                )
                    in
                    ( { model | filter = { filter | method = modelFilter }, filterEditor = filterEditor }
                    , Cmd.none
                    )
                Model.From ->
                    let
                        from_ = model.filterEditor.from
                        (from, filterEditor) =
                            if from_ /= "" then
                                ( from_ :: model.filter.from
                                    |> uniqueList
                                , { filterEditor_ | from = "" }
                                )
                            else
                                (model.filter.from, filterEditor_)
                    in
                    ( { model | filter = { filter | from = from }, filterEditor = filterEditor}
                    , Cmd.none
                    )
                Model.To ->
                    let
                        to_ = model.filterEditor.to
                        (to, filterEditor) =
                            if to_ /= "" then
                                ( to_ :: model.filter.to
                                    |> uniqueList
                                , { filterEditor_ | to = "" }
                                )
                            else 
                                ( model.filter.to, filterEditor_)
                    in
                    ( { model | filter = { filter | to = to }, filterEditor = filterEditor}
                    , Cmd.none
                    )

        DeleteFilter t i ->
            let
                withoutIndex list = 
                    List.map (\(_, v) -> v) <| List.filter (\(idx, _) -> idx /= i ) <| List.indexedMap Tuple.pair  list
                filter_ = model.filter
                filter = case t of
                    Model.Status ->
                        { filter_ | status = withoutIndex model.filter.status }
                    Model.Method ->
                        { filter_ | method = withoutIndex model.filter.method }
                    Model.From ->
                        { filter_ | from = withoutIndex model.filter.from }
                    Model.To ->
                        { filter_ | to = withoutIndex model.filter.to }
            in
            ( { model | filter = filter }
            , Cmd.none
            )
        
        EditFilterEditor t v ->
            let
                filterEditor_ = model.filterEditor
                filterEditor = case t of
                    Model.Status ->
                        { filterEditor_ | status = v }
                    Model.Method ->
                        { filterEditor_ | method = v}
                    Model.From ->
                        { filterEditor_ | from = v }
                    Model.To ->
                        { filterEditor_ | to = v }
            in
            ( { model | filterEditor = filterEditor }
            , Cmd.none
            )

subscriptions : Model.Model -> Sub Msg
subscriptions model =
    sessionReciever RecvSession


-- FUNC

uniqueList : List a -> List a
uniqueList l = 
    let
        incUnique : a -> List a -> List a
        incUnique elem lst = 
            if List.member elem lst then
                lst
            else
                elem :: lst
    in
        List.foldr incUnique [] l
