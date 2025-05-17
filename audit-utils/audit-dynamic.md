PROCESSES:

Onboarding (using audit-notes.md template)
    while read the docs complete:
        Title
        Protocol about
        Roles
        Audit Scope
        Compatibilities
            Solc version
            Chains for production
        Know Issues
        Project Stats

Search the invariants
    Reading onboard Doc:
        add to LIST::Invariant::Not Testeables
        add to LIST::Invariant::Testeables

Fuzzing
    Make a test for all on:
    LIST::Invariants::Testeables

Automated analisis
    slitter
    aderyn
    compiler warning/errors

Manual analisis
    check imports for unknow EIP/ERC/Tokens/Protocols
    check unused from:
        internalfunctions
        variables
        types
        imports
        events
        errors
        interfaces
        modifiers
    check exploits/bugs/inconsistencies from taking in count the LIST::restrictions:
        state variables
        constructor
        public functions
        external functions
        fallback function
        receive function


Research Unknow EIP/ERC/Tokens/Protocols
    LIST::Unknow EIP/ERC/Tokens/Protocols

LISTS:
    restrictions
        scope
        know issues
    Unknow EIP/ERC/Tokens/Protocols
    Invariants
        divide it on:
            Testebles
            Not Testeables

--------------------------------------------------------------------------
MAIN PROCESS:
1. Onboarding
2. Automated analisis
3. Search the invariants
4. Fuzzing
5. Manual analisis
6. Reporting