module Clock exposing (Model)

import Browser
import Browser.Dom
import Browser.Events
import Html exposing (Html, div)
import Html.Attributes exposing (style)
import Svg exposing (Svg, circle, g, line, path, polygon, svg)
import Svg.Attributes exposing (cx, cy, d, fill, fillOpacity, opacity, points, r, stroke, transform, viewBox, width, x1, x2, y1, y2)
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



-- MODEL


type alias TimeOfDay =
    { hour : Int
    , minute : Int
    , second : Int
    }


type alias Model =
    { time : TimeOfDay
    , timeZone : Time.Zone
    , clockWidth : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { time = TimeOfDay 0 0 0
      , timeZone = Time.utc
      , clockWidth = "300px"
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
            [ svg [ viewBox "0 0 100 100", width model.clockWidth ]
                (clockFn model.time)
            ]
        ]


clockFn : TimeOfDay -> List (Svg Msg)
clockFn theDateNow =
    let
        beginTime : TimeOfDay
        beginTime =
            { hour = 14
            , minute = 0
            , second = 0
            }

        endTime : TimeOfDay
        endTime =
            { hour = 20
            , minute = 0
            , second = 0
            }
    in
    [ g [ fill "black", stroke "black", transform "translate(50,50)" ]
        (clockFace
            ++ segment beginTime endTime
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


segment : TimeOfDay -> TimeOfDay -> List (Svg msg)
segment startTime endTime =
    let
        startAngle : Float
        startAngle =
            degrees (minuteToAngle (hourMinute startTime))

        endAngle : Float
        endAngle =
            degrees (minuteToAngle (hourMinute endTime))

        outerEnd =
            48

        innerStart =
            42

        parts =
            String.join " "
                [ pathMoveTo (cos startAngle * innerStart) (sin startAngle * innerStart)
                , pathLineTo (cos startAngle * outerEnd) (sin startAngle * outerEnd)
                , arcToOuter outerEnd (cos endAngle * outerEnd) (sin endAngle * outerEnd)
                , pathLineTo (cos endAngle * innerStart) (sin endAngle * innerStart)
                , arcToInner innerStart (cos startAngle * innerStart) (sin startAngle * innerStart)
                ]
    in
    [ path [ d parts, fill "green", stroke "green", opacity "0.5" ] []
    ]


pathMoveTo : Float -> Float -> String
pathMoveTo x y =
    "M " ++ String.fromFloat x ++ " " ++ String.fromFloat y


pathLineTo : Float -> Float -> String
pathLineTo x y =
    "L " ++ String.fromFloat x ++ " " ++ String.fromFloat y


arcToOuter : Int -> Float -> Float -> String
arcToOuter r x y =
    String.join " "
        [ "A"
        , String.fromInt r
        , String.fromInt r
        , "0 0 1"
        , String.fromFloat x
        , String.fromFloat y
        ]


arcToInner : Int -> Float -> Float -> String
arcToInner r x y =
    String.join " "
        [ "A"
        , String.fromInt r
        , String.fromInt r
        , "0 0 0"
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
