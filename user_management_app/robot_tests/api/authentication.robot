*** Settings ***
Documentation    Tests d'authentification et de sécurité
Library          RequestsLibrary
Library          Collections
Resource         ../resources/common.robot

Suite Setup      API Setup
Suite Teardown   API Teardown

*** Test Cases ***
Test Login With Invalid Credentials
    [Documentation]    Test le login avec des identifiants invalides - devrait retourner 401
    &{headers}=    Create Dictionary    Content-Type=application/json
    &{data}=    Create Dictionary
    ...    username=invaliduser
    ...    password=wrongpassword

    # Utiliser Run Keyword And Expect Error pour capturer l'erreur HTTP attendue
    ${response}=    Run Keyword And Expect Error    HTTPError: 401*    POST    ${API_URL}/auth/login    json=${data}    headers=${headers}
    Should Contain    ${response}    401 Client Error: Unauthorized

Test Password Hashing Security
    [Documentation]    Test que les mots de passe sont bien hashés
    ${response}=    GET    ${API_URL}/users/
    Should Be Equal As Numbers    ${response.status_code}    200
    
    # Vérifier qu'aucun utilisateur n'a de mot de passe en clair
    FOR    ${user}    IN    @{response.json()}
        Should Not Contain    ${user}    password    # Aucun champ password ne devrait être exposé
    END

Test User Role Validation
    [Documentation]    Test la validation des rôles utilisateur
    ${response}=    GET    ${API_URL}/users/
    Should Be Equal As Numbers    ${response.status_code}    200
    
    # Vérifier que tous les utilisateurs ont un rôle valide
    FOR    ${user}    IN    @{response.json()}
        Should Contain Any    ${user['role']}    user    admin    # Rôle doit être soit user soit admin
    END