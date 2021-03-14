load("@bazel_skylib//lib:paths.bzl", "paths")
load("//dotnet/private:providers.bzl", "DotnetLibraryInfo")
load("//dotnet/private/actions:xml.bzl", "element", "inline_element")
load(
    "//dotnet/private/actions:common.bzl",
    "STARTUP_DIR",
    "built_path",
    "make_dotnet_args",
    "make_dotnet_env",
)
load("//dotnet/private:common.bzl", "dotnetos_to_exe_extension", "dotnetos_to_library_extension")

def emit_assembly(ctx, is_executable):
    """Compile a dotnet assembly with the provided project template

    Args:
        ctx: a ctx with //dotnet/private/rules:common.bzl.DOTNET_ATTRS
        is_executable: if the assembly should be executable
    Returns:
        Tuple: the emitted assembly and all outputs
    """
    toolchain = ctx.toolchains["@my_rules_dotnet//dotnet:toolchain"]
    tfm = ctx.attr.target_framework
    library_infos = depset(
        direct = [dep[DotnetLibraryInfo] for dep in ctx.attr.deps],
        transitive = [dep[DotnetLibraryInfo].deps for dep in ctx.attr.deps],
    )
    outputs = []
    output_dir = tfm

    library_extension = dotnetos_to_library_extension(toolchain.default_dotnetos)

    intermediate_output_dir, assembly, pdb = _declare_output_files(ctx, toolchain, tfm, outputs, is_executable, library_extension, library_infos)
    proj = _make_project_file(ctx, toolchain, is_executable, tfm, outputs, library_infos)
    args = make_dotnet_args(ctx, toolchain, "build", proj, intermediate_output_dir.msbuild_path, output_dir)
    env = make_dotnet_env(toolchain)

    dep_files = []
    for li in library_infos.to_list():
        dep_files.extend([li.assembly, li.pdb])

    sdk = toolchain.sdk
    ctx.actions.run(
        mnemonic = "DotnetBuild",
        inputs = (
            ctx.files.srcs +
            [proj] +
            dep_files +
            sdk.packs + sdk.shared + sdk.sdk_files +
            sdk.fxr
        ),
        outputs = outputs,
        executable = toolchain.sdk.dotnet,
        arguments = [args],
        env = env,
    )
    print(ctx.label)
    for o in outputs:
        print(o)
    return assembly, pdb, outputs

def _declare_output_files(ctx, toolchain, tfm, outputs, is_executable, library_extension, library_infos):
    output_dir = tfm

    # primary outputs
    extension = dotnetos_to_exe_extension(toolchain.default_dotnetos) if is_executable else library_extension
    assembly = built_path(ctx, outputs, output_dir + "/" + ctx.label.name + extension)
    output_extensions = []

    if is_executable:
        output_extensions.extend([
            library_extension,  # already declared before this method if it is not executable
            ".runtimeconfig.dev.json",  # todo find out when this is NOT output
            ".runtimeconfig.json",
        ])

    #     tfm_files = [
    #     ".AssemblyInfo.cs",
    # ]

    # for f in tfm_files:
    #     name = prefix + f
    #     intermediate_names.append(paths.join(tfm, name))
    output_extensions.append(".deps.json")

    # todo toggle this when not debug
    pdb = built_path(ctx, outputs, output_dir + "/" + ctx.label.name + ".pdb")
    for ext in output_extensions:
        built_path(ctx, outputs, output_dir + "/" + ctx.label.name + ext)

    for li in library_infos.to_list():
        for f in (li.assembly, li.pdb):
            built_path(ctx, outputs, paths.join(output_dir, f.basename))

    # intermediate outputs
    intermediate_base = built_path(ctx, outputs, "obj", True)
    intermediate_output = built_path(ctx, outputs, intermediate_base.msbuild_path + tfm, True)

    return intermediate_output, assembly, pdb

def _make_project_file(ctx, toolchain, is_executable, tfm, outputs, library_infos):
    # intermediate file, not an output, don't add to outputs
    proj = ctx.actions.declare_file(ctx.label.name + ".csproj")

    output_type = element("OutputType", "Exe") if is_executable else ""

    compile_srcs = [
        inline_element("Compile", {"Include": paths.join(STARTUP_DIR, src.path)})
        for src in depset(ctx.files.srcs).to_list()
    ]

    msbuild_properties = [
    ]

    references = [
        element(
            "Reference",
            element(
                "HintPath",
                paths.join(STARTUP_DIR, li.assembly.path),
            ),
            {
                "Include": paths.split_extension(
                    li.assembly.basename,
                )[0],
            },
        )
        for li in library_infos.to_list()
    ]

    ctx.actions.expand_template(
        template = ctx.file._proj_template,
        output = proj,
        is_executable = False,
        substitutions = {
            "{compile_srcs}": "\n".join(compile_srcs),
            "{tfm}": tfm,
            "{output_type}": output_type,
            "{msbuild_properties}": "\n".join(msbuild_properties),
            "{references}": "\n".join(references),
        },
    )
    return proj
