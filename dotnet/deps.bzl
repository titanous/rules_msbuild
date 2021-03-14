load(
    "//dotnet/private:deps.bzl",
    _dotnet_rules_dependencies = "dotnet_rules_dependencies",
)
load(
    "//dotnet/private/nuget:repository.bzl",
    _nuget_config = "nuget_config",
)
load(
    "//dotnet/private:sdk.bzl",
    _dotnet_download_sdk = "dotnet_download_sdk",
    _dotnet_register_toolchains = "dotnet_register_toolchains",
)

dotnet_rules_dependencies = _dotnet_rules_dependencies
dotnet_register_toolchains = _dotnet_register_toolchains
dotnet_download_sdk = _dotnet_download_sdk

nuget_config = _nuget_config
