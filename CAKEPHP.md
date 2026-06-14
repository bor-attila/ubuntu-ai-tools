## CakePHP framework
### General rules
* This project targets CakePHP 5.x. Assume the latest 5.x minor release unless told otherwise.
* The framework is CakePHP. General documentation: https://book.cakephp.org/5.x/
* The framework's API documentation: https://api.cakephp.org/5.x/namespace-Cake.html
* Use the synapse MCP (https://github.com/josbeir/cakephp-synapse) or the documentation directly if the MCP does not exist.
* If the synapse MCP is available, run a reindex once at the start of every session.
* Always use the CakePHP's conventions for naming things: https://book.cakephp.org/5.x/intro/conventions.html
* If you create a method always document it and put yourself as an author (AI provider and model name)
* In app.php don't modify errorLevel
* Always use the latest methods. If a method is marked as deprecated, try to find the alternative in migration guides https://book.cakephp.org/5.x/appendices/migration-guides.html
### Routing
* Prioritize implicit routing provided by the framework
### Controller
* If you are unsure about the response content format (HTML or JSON) ask, don't guess.
### ORM rules
* When DB-specific behavior matters, detect the current database engine from the connection config in app.php (`Datasources.default.driver`). If unsure, ask.
* Avoid raw expressions. Use the query builder. Only fall back to a raw expression when the query genuinely can't be expressed through the builder (e.g. DB-specific SQL or window functions), and document why.
* In controller classes use fetchTable ONLY when the Table is not the controller's default table (use the default table directly otherwise); prefer fetchTable over creating local fields: https://book.cakephp.org/5.x/controllers.html#loading-additional-tables-models
* In table classes non-trivial datatypes should be explicitly defined (expl.: JSON) https://book.cakephp.org/5.x/orm/database-basics.html#data-types
* in case of enums in migration field should be a basic VARCHAR datatype and the framework's BakedEnum MUST BE USED https://book.cakephp.org/5.x/orm/database-basics.html#enum-type
* In case of multilanguage website use always use Shadowtables for new created tables what are requested to be multilanguage. https://book.cakephp.org/5.x/orm/behaviors/translate.html#translate
* If you need to format results from database always use formatResults https://api.cakephp.org/5.x/class-Cake.ORM.Query.SelectQuery.html#formatResults()
* When you pass a Cake\ORM\Query instance to view you don't need to fetch the data - leave it to be evaluated lazily
### Baking
* Prefer `bin/cake bake` for generating controllers, models, entities and templates to stay convention-compliant instead of hand-writing boilerplate. https://book.cakephp.org/bake/3.x/en/index.html
### Testing
* Write or update PHPUnit tests for every new method or behavior change.
* Use fixtures and follow the framework's testing conventions. https://book.cakephp.org/5.x/development/testing.html
* Run the suite with `composer test` (or `vendor/bin/phpunit`) and make sure it passes before considering a task done.
### Extendibility
* If feature is requested and there is a plugin for it, must be suggested
* List of plugins: https://github.com/friendsofcake/awesome-cakephp
### Logging
* Do not write into the logs by calling Log class static methods. Use LogTrait. https://book.cakephp.org/5.x/core-libraries/logging.html#writing-to-logs
### Formatting
* Always follow the CS https://book.cakephp.org/5.x/contributing/cakephp-coding-conventions.html#coding-standards
* Always fix the coding standard with `composer cs-fix` after that, check the output with `composer cs-check` and try to fix everything what is possible.