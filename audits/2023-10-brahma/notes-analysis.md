mermaid drawing diagram

Previous audit does not work on console fallback and OPhandler

So focus on:
- Console
- Policy
- Executor

```mermaid


    SubAccount |Owned|<--|1| ConsoleAccount
    Operators --> SubAccount
    ConsoleAccount --> |Allow operations| Ops
    Operators --> |call| Ops
    SubAccount --> |Enable| Executions
    Executions --> |call| Executions

SubAccount is gnosis safe with modules
Modules are ConsoleAccount, SafeModerator, ExecutorPlugin

```

Gnosis safe allow delegate selfdestruct and upgrade to a new contract so all user module include into safe are never really safe.