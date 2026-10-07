# language: en
Feature: Slack thread replies
  As a Slack user
  I want bot replies to land in a thread
  So that channels stay readable

  # --- Replies ---

  @behavior @happy-path
  # @covered-by: packages/slack-bot/src/__tests__/hitl.test.ts
  Scenario: Reply opens a thread
    Given a message in a channel
    When the bot replies
    Then the reply is posted in the message's thread

  @behavior @error-handling
  # @covered-by: packages/slack-bot/src/__tests__/hitl.test.ts
  Scenario: Reply to a deleted message is dropped
    Given a message that was deleted
    When the bot replies
    Then nothing is posted and the event is logged
