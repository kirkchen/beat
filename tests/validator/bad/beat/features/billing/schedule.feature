Feature: Billing schedule

  # --- Monthly ---

  @behavior
  Scenario: Monthly billing adjusts for short months
    Given a subscription started on the 31st
    When calculateNextTransactionDate(subscription) runs in February
    Then the next date clamps to 28 or 29 with weight 0.85

  @behavior @e2e @custom-tag
  # @covered-by: src/billing/__tests__/missing.test.ts
  Scenario: TODO describe
    Given something
