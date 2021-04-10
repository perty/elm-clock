module Clock exposing (Model)

import Browser
import Browser.Dom
import Browser.Events
import Html exposing (Html, button, div, input, option, select, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (style, type_, value)
import Html.Events as Events
import Svg exposing (Svg, circle, g, line, path, polygon, svg)
import Svg.Attributes exposing (cx, cy, d, fill, fillOpacity, opacity, points, r, stroke, transform, viewBox, width, x1, x2, y1, y2)
import Svg.Events exposing (onClick)
import Task
import Time
import TimeZone


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- Messages


type Msg
    = Tick Time.Posix
    | ReceiveTimeZone (Result TimeZone.Error ( String, Time.Zone ))
    | GetViewPort Browser.Dom.Viewport
    | WindowResize Int Int
    | ShowBusyDialog
    | UpdateStartHour String
    | UpdateStartMinute String
    | UpdateEndHour String
    | UpdateEndMinute String
    | UpdateColour String
    | AddBusyClicked
    | DoneButtonClicked
    | RemoveBusy Busy



-- MODEL


type alias TimeOfDay =
    { hour : Int
    , minute : Int
    , second : Int
    }


type alias Busy =
    { startTime : TimeOfDay
    , endTime : TimeOfDay
    , colour : String
    }


type alias Model =
    { time : TimeOfDay
    , timeZone : Time.Zone
    , clockWidth : String
    , showBusyDialog : Bool
    , busyHours : List Busy
    , startHourInput : String
    , startMinuteInput : String
    , endHourInput : String
    , endMinuteInput : String
    , colourInput : String
    , error : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { time = TimeOfDay 0 0 0
      , timeZone = Time.utc
      , clockWidth = "300px"
      , showBusyDialog = False
      , busyHours = []
      , startHourInput = ""
      , startMinuteInput = ""
      , endHourInput = ""
      , endMinuteInput = ""
      , colourInput = ""
      , error = ""
      }
    , Cmd.batch
        [ TimeZone.getZone |> Task.attempt ReceiveTimeZone
        , Browser.Dom.getViewport |> Task.perform GetViewPort
        ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick newTime ->
            ( { model | time = dateFromPosix model.timeZone newTime }, Cmd.none )

        ReceiveTimeZone (Ok ( _, zone )) ->
            ( { model | timeZone = zone }, Cmd.none )

        ReceiveTimeZone (Err _) ->
            ( model, Cmd.none )

        GetViewPort viewPort ->
            ( { model | clockWidth = calculateWidth <| Basics.round <| Basics.min viewPort.viewport.width viewPort.viewport.height }
            , Cmd.none
            )

        WindowResize width height ->
            ( { model | clockWidth = calculateWidth <| Basics.min width height }
            , Cmd.none
            )

        ShowBusyDialog ->
            ( { model | showBusyDialog = True }
            , Cmd.none
            )

        UpdateStartHour hour ->
            ( { model | startHourInput = hour }
            , Cmd.none
            )

        UpdateStartMinute minute ->
            ( { model | startMinuteInput = minute }
            , Cmd.none
            )

        UpdateEndHour hour ->
            ( { model | endHourInput = hour }
            , Cmd.none
            )

        UpdateEndMinute minute ->
            ( { model | endMinuteInput = minute }
            , Cmd.none
            )

        UpdateColour colour ->
            ( { model | colourInput = colour }
            , Cmd.none
            )

        AddBusyClicked ->
            let
                stringToInt : String -> Int -> Result String Int
                stringToInt string max =
                    String.trim string
                        |> String.toInt
                        |> Result.fromMaybe ("Error parsing string: " ++ string)
                        |> Result.andThen
                            (\h ->
                                if h >= 0 && h < max then
                                    Ok h

                                else
                                    Err ("Must be between 0 and " ++ String.fromInt max ++ ": " ++ string)
                            )

                startHour : Result String Int
                startHour =
                    stringToInt model.startHourInput 24

                startMinute : Result String Int
                startMinute =
                    stringToInt model.startMinuteInput 60

                endHour : Result String Int
                endHour =
                    stringToInt model.endHourInput 24

                endMinute : Result String Int
                endMinute =
                    stringToInt model.endMinuteInput 60

                colour : Result String String
                colour =
                    if String.length model.colourInput > 2 then
                        Ok model.colourInput

                    else
                        Err "No colour selected."

                busy : Result String Busy
                busy =
                    Result.map5
                        (\sh sm eh em c ->
                            { startTime =
                                { hour = sh
                                , minute = sm
                                , second = 0
                                }
                            , endTime =
                                { hour = eh
                                , minute = em
                                , second = 0
                                }
                            , colour = c
                            }
                        )
                        startHour
                        startMinute
                        endHour
                        endMinute
                        colour
            in
            ( case busy of
                Ok b ->
                    { model
                        | busyHours = b :: model.busyHours
                        , startMinuteInput = ""
                        , startHourInput = ""
                        , endMinuteInput = ""
                        , endHourInput = ""
                        , colourInput = ""
                        , error = ""
                    }

                Err error ->
                    { model | error = error }
            , Cmd.none
            )

        DoneButtonClicked ->
            ( { model | showBusyDialog = False }
            , Cmd.none
            )

        RemoveBusy busy ->
            ( { model | busyHours = List.filter (\b -> b /= busy) model.busyHours }
            , Cmd.none
            )


dateFromPosix : Time.Zone -> Time.Posix -> TimeOfDay
dateFromPosix zone time =
    TimeOfDay (Time.toHour zone time) (Time.toMinute zone time) (Time.toSecond zone time)


calculateWidth : Int -> String
calculateWidth min =
    String.fromInt (min - 10) ++ "px"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every second Tick
        , Browser.Events.onResize WindowResize
        ]


second =
    1000



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ style "height" "100%"
        , style "display" "flex"
        , style "align-items" "center"
        , style "justify-content" "center"
        ]
        [ div
            [ style "padding" "10px"
            , style "max-width" model.clockWidth
            ]
            (if model.showBusyDialog then
                [ viewBusyDialog model ]

             else
                [ svg [ viewBox "0 0 100 100", width model.clockWidth ]
                    (clockFn model.busyHours model.time)
                ]
            )
        ]


clockFn : List Busy -> TimeOfDay -> List (Svg Msg)
clockFn busyHours theDateNow =
    [ g [ fill "black", stroke "black", transform "translate(50,50)", onClick ShowBusyDialog ]
        (clockFace
            ++ busySegments busyHours
            ++ hourHand theDateNow
            ++ minutesHand theDateNow
            ++ secondsHand theDateNow
        )
    ]


clockFace : List (Svg Msg)
clockFace =
    [ circle [ cx "0", cy "0", r "49", fill "white" ] []
    , letterE
    , letterL
    ]
        ++ letterM
        ++ tickMarks


letterE =
    polygon [ points "0,0 0,9 1,9 1,8.5 0.5,8.5 0.5,5 0.75,5 0.75,4 0.5,4 0.5,1 1,1 1,0", transform "translate(-3,15)" ] []


letterL =
    polygon [ points "0,0 0,1 0.5,1 0.5,9 1,9 1,8.5 0.5,8.5 0.5,0", transform "translate(0,15)" ] []


letterM =
    [ polygon [ points "0,4 0,9 0.25,9 0.25,4 ", transform "translate(3,15)" ] []
    , polygon [ points "0.25,5 4,5 4,5.5 0.25,5.5 ", transform "translate(3,15)" ] []
    , polygon [ points "4,5.5 4,9 3.75,9 3.75,5.5", transform "translate(3,15)" ] []
    , polygon [ points "2,5.5 2,9 1.75,9 1.75,5.5", transform "translate(3,15)" ] []
    ]


busySegments : List Busy -> List (Svg msg)
busySegments busies =
    List.map (\b -> segment b.startTime b.endTime b.colour) busies


segment : TimeOfDay -> TimeOfDay -> String -> Svg msg
segment startTime endTime colour =
    let
        hour12 : TimeOfDay -> Float
        hour12 time =
            modBy 12 time.hour |> toFloat

        hourMin : TimeOfDay -> Float
        hourMin time =
            hour12 time * 5.0 + toFloat time.minute / 12.0

        time2Angle : TimeOfDay -> Float
        time2Angle time =
            degrees (hourMin time - 15.0) * 360 / 60.0

        startAngle : Float
        startAngle =
            time2Angle startTime

        endAngle : Float
        endAngle =
            time2Angle endTime

        minuteDiff =
            Basics.abs ((endTime.hour * 5 + endTime.minute // 12) - (startTime.hour * 5 + startTime.minute // 12))

        outerEnd =
            48

        innerStart =
            42

        parts =
            String.join " "
                [ pathMoveTo (cos startAngle * innerStart) (sin startAngle * innerStart)
                , pathLineTo (cos startAngle * outerEnd) (sin startAngle * outerEnd)
                , arcToOuter (minuteDiff >= 30) outerEnd (cos endAngle * outerEnd) (sin endAngle * outerEnd)
                , pathLineTo (cos endAngle * innerStart) (sin endAngle * innerStart)
                , arcToInner (minuteDiff >= 30) innerStart (cos startAngle * innerStart) (sin startAngle * innerStart)
                ]
    in
    path [ d parts, fill colour, stroke colour, opacity "0.5" ] []


pathMoveTo : Float -> Float -> String
pathMoveTo x y =
    "M " ++ String.fromFloat x ++ " " ++ String.fromFloat y


pathLineTo : Float -> Float -> String
pathLineTo x y =
    "L " ++ String.fromFloat x ++ " " ++ String.fromFloat y


arcToOuter : Bool -> Int -> Float -> Float -> String
arcToOuter large r x y =
    String.join " "
        [ "A"
        , String.fromInt r
        , String.fromInt r
        , if large then
            "0 1 1"

          else
            "0 0 1"
        , String.fromFloat x
        , String.fromFloat y
        ]


arcToInner : Bool -> Int -> Float -> Float -> String
arcToInner large r x y =
    String.join " "
        [ "A"
        , String.fromInt r
        , String.fromInt r
        , if large then
            "0 1 0"

          else
            "0 0 0"
        , String.fromFloat x
        , String.fromFloat y
        ]


tickMarks : List (Svg Msg)
tickMarks =
    List.map tick (List.range 1 60)


tick : Int -> Svg Msg
tick minute =
    let
        tickStart =
            if modBy 5 minute == 0 then
                "35"

            else
                "42"

        angle =
            String.fromFloat (minuteToAngle minute)
    in
    line [ x1 tickStart, y1 "0", x2 "49", y2 "0", transform ("rotate(" ++ angle ++ ")") ] []


minuteToAngle : Int -> Float
minuteToAngle minute =
    (toFloat minute - 15.0) * 360 / 60.0


hourHand : TimeOfDay -> List (Svg Msg)
hourHand theDateNow =
    let
        angle =
            minuteToAngle (hourMinute theDateNow)
    in
    [ g [ transform ("rotate(" ++ String.fromFloat angle ++ ")") ]
        [ polygon [ points "0,0 4,4 20,0 4, -4", transform "translate(10,0)" ] []
        , xLine "0" "10"
        ]
    ]



-- Which minute should the hour hand point to?


hourMinute : TimeOfDay -> Int
hourMinute theTimeNow =
    modBy 12 theTimeNow.hour * 5 + theTimeNow.minute // 12


minutesHand : TimeOfDay -> List (Svg Msg)
minutesHand theTimeNow =
    let
        angle =
            minuteToAngle theTimeNow.minute
    in
    [ g [ transform ("rotate(" ++ String.fromFloat angle ++ ")") ]
        [ polygon [ points "0,0 2,2 29,0 2, -2", transform "translate(5,0)" ] []
        , xLine "0" "5"
        ]
    ]


secondsHand : TimeOfDay -> List (Svg Msg)
secondsHand theTimeNow =
    let
        angle =
            minuteToAngle theTimeNow.second
    in
    [ g [ transform ("rotate(" ++ String.fromFloat angle ++ ")") ]
        [ xLine "-5" "40"
        , circle [ cx "0", cy "0", r "5", fillOpacity "0", transform "translate(30,0)" ] []
        ]
    ]


xLine : String -> String -> Svg Msg
xLine start end =
    line [ x1 start, y1 "0", x2 end, y2 "0" ] []



-- Busy managing


viewBusyDialog : Model -> Html Msg
viewBusyDialog model =
    div []
        [ text "Busy hours"
        , viewBusyHours model.busyHours
        , viewBusyControls model
        ]


viewBusyHours : List Busy -> Html Msg
viewBusyHours busies =
    table []
        [ thead []
            [ tr []
                [ th [] [ text "Start" ]
                , th [] [ text "End" ]
                , th [] [ text "Colour" ]
                , th [] [ text "Remove" ]
                ]
            ]
        , tbody [] (List.map viewBusy busies)
        ]


viewBusy : Busy -> Html Msg
viewBusy busy =
    tr []
        [ td [] [ text <| busyToString busy.startTime ]
        , td [] [ text <| busyToString busy.endTime ]
        , td [] [ text busy.colour ]
        , td [] [ button [ Events.onClick (RemoveBusy busy) ] [ text "X" ] ]
        ]


busyToString : TimeOfDay -> String
busyToString timeOfDay =
    String.join ":" [ String.fromInt timeOfDay.hour, String.fromInt timeOfDay.minute ]


viewBusyControls : Model -> Html Msg
viewBusyControls model =
    div []
        [ div []
            [ input [ Events.onInput UpdateStartHour, value model.startHourInput ] []
            , input [ Events.onInput UpdateStartMinute, value model.startMinuteInput ] []
            , input [ Events.onInput UpdateEndHour, value model.endHourInput ] []
            , input [ Events.onInput UpdateEndMinute, value model.endMinuteInput ] []
            , colorSelector model
            , button
                [ type_ "submit"
                , Events.onClick AddBusyClicked
                ]
                [ text "Add" ]
            ]
        , text model.error
        , button
            [ type_ "submit"
            , Events.onClick DoneButtonClicked
            , width "100%"
            ]
            [ text "Done" ]
        ]


colorSelector : Model -> Html Msg
colorSelector _ =
    let
        color2Option colour =
            option [ value colour ] [ text colour ]

        options =
            List.map color2Option [ "pick a color", "red", "green", "yellow", "blue", "grey" ]
    in
    select [ Events.onInput UpdateColour ] options
