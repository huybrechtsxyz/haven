# Custom Integrations

Place `.py` files here to register custom integrations with the xyz platform.

Each file must define a `register()` function that calls
`IntegrationFactory.register_type(type_str, cls)`.

See `xyz help integrations` for documentation.
