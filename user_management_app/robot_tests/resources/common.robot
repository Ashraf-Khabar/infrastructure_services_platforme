*** Settings ***
Library          RequestsLibrary
Library          Collections
Library          String

*** Variables ***
${API_URL}       http://localhost:5000
${BROWSER}       chrome

*** Keywords ***
API Setup
    Create Session    api_session    ${API_URL}    verify=true

API Teardown
    Delete All Sessions

Generate Random Email
    [Arguments]    ${length}=8
    ${random_string}=    Generate Random String    ${length}    [LOWER]
    [Return]    ${random_string}@example.com

Generate Random Username
    [Arguments]    ${length}=6
    ${random_string}=    Generate Random String    ${length}    [LOWER]
    [Return]    ${random_string}

Validate Response Status
    [Arguments]    ${response}    ${expected_status}=200
    Should Be Equal As Numbers    ${response.status_code}    ${expected_status}

Validate Response Contains
    [Arguments]    ${response}    ${field}    ${expected_value}
    Should Be Equal    ${response.json()}[${field}]    ${expected_value}