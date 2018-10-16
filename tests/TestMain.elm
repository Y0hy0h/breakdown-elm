module TestMain exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (..)
import Main exposing (Model, Msg(..), initModel, update)
import Tasks
import Test exposing (..)


suite : Test
suite =
    describe "messages"
        [ test "NoOp keeps model the same" <|
            \_ ->
                update NoOp initModel
                    |> expectModelEquals initModel
        , test "UpdateNewTask saves the new task" <|
            \_ ->
                update (UpdateNewTask "i am an edit") initModel
                    |> expectModelEquals { initModel | newTask = "i am an edit" }
        , describe "AddNewTask"
            [ test "saves valid task and resets new task" <|
                \_ ->
                    let
                        rawAction =
                            "I am a valid action."
                    in
                    testWithAction rawAction
                        (\action ->
                            update AddNewTask { initModel | newTask = rawAction }
                                |> expectModelEquals
                                    { initModel
                                        | newTask = ""
                                        , currentTasks = Tasks.appendTask action initModel.currentTasks
                                    }
                        )
            , test "does not save valid task, but resets new task" <|
                \_ ->
                    update AddNewTask { initModel | newTask = "   " }
                        |> expectModelEquals { initModel | newTask = "" }
            ]
        , test "DoTask moves task from current collection to done" <|
            \_ ->
                testWithAction "Do me"
                    (\action ->
                        let
                            ( task, currentTasks ) =
                                Tasks.appendAndGetTask action initModel.currentTasks

                            init =
                                { initModel | currentTasks = currentTasks }
                        in
                        update (DoTask <| Tasks.getId task) init
                            |> Expect.all
                                [ \( model, _ ) -> Expect.equal initModel.currentTasks model.currentTasks
                                , \( model, _ ) -> Expect.equal (Tasks.appendTask action initModel.doneTasks) model.doneTasks
                                ]
                    )
        , test "UndoTask moves task from done collection to current" <|
            \_ ->
                testWithAction "Undo me"
                    (\action ->
                        let
                            ( task, doneTasks ) =
                                Tasks.appendAndGetTask action initModel.doneTasks

                            init =
                                { initModel | doneTasks = doneTasks }
                        in
                        update (UndoTask <| Tasks.getId task) init
                            |> Expect.all
                                [ \( model, _ ) -> expectEquivalentCollections initModel.doneTasks model.doneTasks
                                , \( model, _ ) -> expectEquivalentCollections (Tasks.appendTask action initModel.currentTasks) model.currentTasks
                                ]
                    )
        , describe "StartEdit"
            [ todo "sets up edit mode with the correct information"
            , todo "applies edit in progress"
            ]
        , todo "ApplyEdit applies the edit in progress"
        , todo "CancelEdit restores state before edit"
        , todo "DeleteTask removes a task"
        , todo "BackgroundClicked applies the current edit and stops editing"
        ]


expectModelEquals : Model -> ( Model, Cmd Msg ) -> Expectation
expectModelEquals expected =
    Tuple.first >> Expect.equal expected


testWithAction : String -> (Tasks.Action -> Expectation) -> Expectation
testWithAction rawAction test =
    case Tasks.actionFromString rawAction of
        Just action ->
            test action

        Nothing ->
            Expect.fail "Expected test string to be valid action."


expectEquivalentCollections : Tasks.Collection a -> Tasks.Collection b -> Expectation
expectEquivalentCollections first second =
    Expect.equalLists (toActionList first) (toActionList second)


{-| Used for comparing whether two collections compare the same actions, disregarding their ids.
-}
toActionList : Tasks.Collection c -> List String
toActionList =
    Tasks.toList >> List.map Tasks.readAction