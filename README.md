# ORM Framework for FiveM

This ORM framework is designed to provide an efficient and database-agnostic way to interact with relational databases in FiveM. It supports common ORM functionalities such as model definition and querying while maintaining a clean API similar to Django's ORM. Relationship handling is planned but not yet fully implemented.

## Features

- **Model Definition**: Define models using a clean, Django-like syntax.
- **QuerySet API**: Chainable query methods like `filter`, `get`, `select_related`.
- **Database-Agnostic Design**: Query building is handled at the ORM level, while SQL generation and execution are delegated to the database adapter.
- **Relationship Handling**: Initial implementation for `ForeignKey` and `ManyToManyField` relationships is present, but full functionality is not yet in effect.
- **Mock Adapters for Testing**: Allows testing the ORM logic without launching FiveM.

## Directory Structure

```
src/
  alg.lua
  
  adapters/
      adapter.lua
      mysql_adapter.lua
  
  library/
      mysql_async_mock.lua
  
  models/
      base_model.lua
      define_class.lua
      fields.lua
      model_manager.lua
      q.lua
      queryset.lua
      result_processor.lua
  
  server/
      package-lock.json
      package.json
      test-server.js  # The back-end test server
```

## QuerySet Methods

### Basic Queries

```lua
Book.objects:filter({title = "The Great Gatsby"}):get(function(results, err)
    if err then print("Error:", err) else print("Results:", results) end
end)
```

### Selecting Related Fields

```lua
Book.objects:select_related({"author", "publisher"}):get(function(results)
    print(results)
end)
```

## Adapters

The ORM supports different adapters to connect with various databases. The adapter is responsible for converting ORM queries into SQL statements and executing them against the database.

### MySQL Adapter

This is the default adapter for interacting with MySQL databases.

### Mock Adapter

The Mock Adapter creates a connection via `mysql2` and receives POST requests from the Lua adapter (`mysql_async_mock`). The `mysql_async_mock` module sends this data using unconventional workarounds, such as `io.popen`, to avoid adding more dependencies. This setup is intended for development purposes only, allowing ORM testing without directly running FiveM.

## Usage Notes

- The `BaseModel` remains database-agnostic, and all SQL-specific logic resides in the adapters.
- QuerySet methods like `select_related` and `filter` modify the query structure but do not execute it directly.
- Always use adapters correctly: the Mock Adapter is a workaround to prevent using the MySQL Async library, which has certain FiveM dependencies that are unavailable in a standalone environment. It should only be used for testing purposes.

## Future Improvements

- Add support for additional databases beyond MySQL.
- Implement caching mechanisms for optimized query performance.
- Fully implement relationship handling to support nested joins, advanced prefetching, and more dynamic relationship resolution.

