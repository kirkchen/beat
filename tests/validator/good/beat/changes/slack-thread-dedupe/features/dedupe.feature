# language: en
Feature: HITL button dedupe
  As an operator
  I want a double-clicked button to act once
  So that runs are not duplicated

  @behavior @happy-path
  # @covered-by: packages/slack-bot/src/__tests__/hitl.test.ts
  Scenario: Duplicate button press is ignored
    Given a gate with one button
    When the button is pressed twice within a second
    Then only one reply is recorded
