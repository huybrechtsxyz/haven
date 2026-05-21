# Custom Integrations

Place `.py` files here to register custom integrations with the Strata.

Each file must define a `register()` function that calls
`IntegrationFactory.register_type(type_str, cls)`.

See `strata help integrations` for documentation.
