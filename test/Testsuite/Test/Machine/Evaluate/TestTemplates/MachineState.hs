{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}

-- | Functions and types required to implement tests that check whether
-- a certain closure is reduced to the expected form by the STG.
module Test.Machine.Evaluate.TestTemplates.MachineState (
    MachineStateTestSpec(..),
    defSpec,
    machineStateTest,
) where



import qualified Data.List                             as L
import qualified Data.List.NonEmpty                    as NE
import           Data.Text                             (Text)
import qualified Data.Text                             as T
import           Data.Text.Prettyprint.Doc
import           Data.Text.Prettyprint.Doc.Render.Text

import Stg.Language
import Stg.Language.Prettyprint
import Stg.Machine
import Stg.Machine.Types
import Stg.Parser.QuasiQuoter   (stg)

import Test.Machine.Evaluate.TestTemplates.Util
import Test.Tasty
import Test.Tasty.HUnit



-- | Specify a test that is based on a certain predicate to hold in an
-- evaluation step.
data MachineStateTestSpec = MachineStateTestSpec
    { testName :: Text
        -- ^ Test name to display in the test overview.

    , successPredicate :: StgState -> Bool
        -- ^ Test predicate to determine whether the desired state has been
        -- reached.

    , failPredicate :: StgState -> Bool
        -- ^ Fail if this predicate holds. This can be used to constrain the
        -- heap size during the test, for example.

    , allSatisfied :: [StgState -> Bool]
        -- ^ All of these predicates have to hold for some (not necessarily the
        -- same) intermediate states. This is for example useful to check
        -- whether at some point rule 1 was applied, and at another rule 2.

    , source :: Program
        -- ^ STG program to run.

    , maxSteps :: Integer
        -- ^ Maximum number of steps to take

    , performGc :: PerformGc
        -- ^ Perform GC under which conditions?

    , failWithInfo :: Bool
        -- ^ Print program code and final state on test failure? Very useful for
        -- fixing tests.
    }

defSpec :: MachineStateTestSpec
defSpec = MachineStateTestSpec
    { testName             = "Default machine state test template"
    , successPredicate     = "main" `isLambdaForm` [stg| \ -> Success |]
    , failPredicate        = const False
    , allSatisfied         = []
    , source               = [stg| main = \ -> DummySource |]
    , maxSteps             = 1024
    , performGc            = PerformGc (const (Just triStateTracing))
    , failWithInfo         = False }

-- | Evaluate the @main@ closure of a STG program, and check whether the machine
-- state satisfies a predicate when it is evaluated.
machineStateTest :: MachineStateTestSpec -> TestTree
machineStateTest testSpec = testCase (T.unpack (testName testSpec)) test
  where
    program = initialState "main" (source testSpec)
    states = evalsUntil (RunForMaxSteps (maxSteps testSpec))
                        (HaltIf (successPredicate testSpec))
                        (performGc testSpec)
                        program
    finalState = NE.last states

    test :: Assertion
    test = case L.find (failPredicate testSpec) states of
        Just badState -> fail_failPredicateTrue testSpec badState
        Nothing -> case NE.toList states `allSatisfyAtSomePoint` allSatisfied testSpec of
            True -> case stgInfo finalState of
                Info HaltedByPredicate _ -> pure ()
                _otherwise -> fail_successPredicateNotTrue testSpec finalState
            False -> (assertFailure . T.unpack)
                "No intermediate state satisfied the required predicate."

failWithInfoInfoText :: Doc ann
failWithInfoInfoText = "Run test case with failWithInfo to see the final state."

fail_successPredicateNotTrue
    :: MachineStateTestSpec
    -> StgState
    -> Assertion
fail_successPredicateNotTrue
    testSpec
    finalState
  = (assertFailure . T.unpack . renderStrict . layoutPretty defaultLayoutOptions . vsep)
        [ "STG failed to satisfy predicate: "
            <> prettyStgi (stgInfo finalState)
        , if failWithInfo testSpec
            then vsep
                [ hang 4 (vsep ["Program:", prettyStgi (source testSpec)])
                , hang 4 (vsep ["Final state:", prettyStgi finalState]) ]
            else failWithInfoInfoText ]

fail_failPredicateTrue
    :: MachineStateTestSpec
    -> StgState
    -> Assertion
fail_failPredicateTrue
    testSpec
    badState
  = (assertFailure . T.unpack . renderStrict . layoutPretty defaultLayoutOptions . vsep)
        [ "Failure predicate held for an intemediate state"
        , if failWithInfo testSpec
            then vsep
                [ hang 4 (vsep ["Program:", prettyStgi (source testSpec)])
                , hang 4 (vsep ["Bad state:", prettyStgi badState]) ]
            else failWithInfoInfoText ]

allSatisfyAtSomePoint
    :: [StgState]
    -> [StgState -> Bool]
    -> Bool
allSatisfyAtSomePoint states (p:ps)
  = L.any p states && allSatisfyAtSomePoint states ps
allSatisfyAtSomePoint _ [] = True
