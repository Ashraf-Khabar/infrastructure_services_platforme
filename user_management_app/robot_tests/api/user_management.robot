*** Settings ***
Documentation    Tests de non-régression pour la gestion des utilisateurs
Library          RequestsLibrary
Library          Collections
Library          String
Resource         ../resources/common.robot
Resource         ../resources/api_client.robot

Suite Setup      API Setup
Suite Teardown   API Teardown

*** Variables ***
${API_URL}       http://localhost:5000
${VALID_USERNAME}    admin
${VALID_PASSWORD}    admin

*** Test Cases ***
Test Health Check Endpoint
    [Documentation]    Vérifie que l'endpoint health fonctionne
    ${response}=    GET    ${API_URL}/health
    Should Be Equal As Numbers    ${response.status_code}    200
    Should Be Equal    ${response.json()['status']}    healthy

Test Get All Users
    [Documentation]    Test la récupération de tous les utilisateurs
    ${response}=    GET    ${API_URL}/users/
    Should Be Equal As Numbers    ${response.status_code}    200
    Should Be True    ${response.json()}    # Vérifie que la réponse n'est pas vide

Test Create New User
    [Documentation]    Test la création d'un nouvel utilisateur
    ${random_email}=    Generate Random String    8    [LOWER]
    ${random_email}=    Set Variable    ${random_email}@example.com
    ${random_username}=    Generate Random String    6    [LOWER]
    
    &{headers}=    Create Dictionary    Content-Type=application/json
    &{data}=    Create Dictionary
    ...    username=${random_username}
    ...    email=${random_email}
    ...    password=testpassword123
    ...    first_name=Test
    ...    last_name=User
    ...    role=user

    ${response}=    POST    ${API_URL}/users/    json=${data}    headers=${headers}
    Should Be Equal As Numbers    ${response.status_code}    200
    Should Be Equal    ${response.json()['username']}    ${random_username}
    Should Be Equal    ${response.json()['email']}    ${random_email}

Test Login Functionality
    [Documentation]    Test la fonctionnalité de login
    &{headers}=    Create Dictionary    Content-Type=application/json
    &{data}=    Create Dictionary
    ...    username=${VALID_USERNAME}
    ...    password=${VALID_PASSWORD}

    ${response}=    POST    ${API_URL}/auth/login    json=${data}    headers=${headers}
    Should Be Equal As Numbers    ${response.status_code}    200
    Should Be Equal    ${response.json()['username']}    ${VALID_USERNAME}
    Should Be Equal    ${response.json()['role']}    admin

Test User Deletion
    [Documentation]    Test la suppression d'un utilisateur
    # D'abord créer un utilisateur
    ${random_email}=    Generate Random String    8    [LOWER]
    ${random_email}=    Set Variable    ${random_email}@example.com
    ${random_username}=    Generate Random String    6    [LOWER]
    
    &{headers}=    Create Dictionary    Content-Type=application/json
    &{data}=    Create Dictionary
    ...    username=${random_username}
    ...    email=${random_email}
    ...    password=testpassword123
    ...    first_name=Test
    ...    last_name=User
    ...    role=user

    ${create_response}=    POST    ${API_URL}/users/    json=${data}    headers=${headers}
    ${user_id}=    Set Variable    ${create_response.json()['id']}

    # Maintenant supprimer l'utilisateur
    ${delete_response}=    DELETE    ${API_URL}/users/${user_id}
    Should Be Equal As Numbers    ${delete_response.status_code}    200

*** Keywords ***
API Setup
    [Documentation]    Setup initial pour les tests API
    Create Session    api_session    ${API_URL}    verify=true

API Teardown
    [Documentation]    Nettoyage après les tests
    Delete All Sessions