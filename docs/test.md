# Test Scope

The Rails behavior suite is `bin/rails test`. It covers the retained Base app, Base com, Base org,
Tech org and operator-tool boundaries. JavaScript checks are defined by the repository package
scripts; this document does not add or replace those checks.

Current acceptance requires host-constrained routing, cross-surface isolation, authorization before
protected writes, explicit failure when RP login dependencies are unavailable, and correct public
Base com behavior. Auth/Visa sign-in and OIDC callback behavior is retired and has no local route or
controller contract.

For test conventions and data setup, follow the loaded repository rules and `test/test_helper.rb`.
