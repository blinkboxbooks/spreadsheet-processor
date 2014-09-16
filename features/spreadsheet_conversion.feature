Feature: Files uploaded by publishers are flagged for processing as soon as possible
  As a publisher who delivers in XLS format
  I want to have my book's (meta)data updated immediately
  So that any incorrect data is corrected as soon as possible

  Background:
    Given there is a publisher called "scholastic"

  Scenario: A valid xls spreadsheet generates ONIX files
    Given the example file "example_spreadsheet.xls" exists
    And the following file is uploaded:
      | filename                | folder     | permissions |
      | example_spreadsheet.xls | scholastic | 0664        |
    And the folder "scholastic/generated_example_spreadsheet.xls" does not exist
    When it is found by the watcher
    Then "scholastic/generated_example_spreadsheet.xls" is a folder
    And these files exist and match their examples:
      | filename                                                       | example_filename      |
      | scholastic/generated_example_spreadsheet.xls/9780111222333.xml | xls-9780111222333.xml |

  Scenario: A valid xlsx spreadsheet generates ONIX files
    Given the example file "example_spreadsheet.xlsx" exists
    And the following file is uploaded:
      | filename                 | folder     | permissions |
      | example_spreadsheet.xlsx | scholastic | 0664        |
    And the folder "scholastic/generated_example_spreadsheet.xlsx" does not exist
    When it is found by the watcher
    Then "scholastic/generated_example_spreadsheet.xlsx" is a folder
    And these files exist and match their examples:
      | filename                                                        | example_filename       |
      | scholastic/generated_example_spreadsheet.xlsx/9780111222333.xml | xlsx-9780111222333.xml |

  Scenario: Old mobcast spreadsheets are marked as .invalid
    Given the example file "mobcast_format.xls" exists
    And the following file is uploaded:
      | filename           | folder     | permissions |
      | mobcast_format.xls | scholastic | 0664        |
    When it is found by the watcher
    Then the file "mobcast_format.xls.invalid" exists

  Scenario: Publisher proprietary spreadsheets are marked as .invalid
    Given the example file "proprietary_format.xls" exists
    And the following file is uploaded:
      | filename               | folder     | permissions |
      | proprietary_format.xls | scholastic | 0664        |
    When it is found by the watcher
    Then the file "proprietary_format.xls.invalid" exists
