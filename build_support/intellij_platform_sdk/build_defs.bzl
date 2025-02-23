"""Convenience methods for plugin_api."""

# The current indirect ij_product mapping (eg. "intellij-latest")
INDIRECT_IJ_PRODUCTS = {
    "intellij-latest": "intellij-2019.2",
    "intellij-latest-mac": "intellij-2019.2-mac",
    "intellij-beta": "intellij-2019.2",
    "intellij-canary": "intellij-2019.3",
    "intellij-ue-latest": "intellij-ue-2019.2",
    "intellij-ue-latest-mac": "intellij-ue-2019.2-mac",
    "intellij-ue-beta": "intellij-ue-2019.2",
    "intellij-ue-canary": "intellij-ue-2019.3",
    "android-studio-latest": "android-studio-3.5",
    "android-studio-beta": "android-studio-3.6",
    "android-studio-beta-mac": "android-studio-3.6-mac",
    "android-studio-canary": "android-studio-4.0",
    "clion-latest": "clion-2019.2",
    "clion-beta": "clion-2019.2",
}

DIRECT_IJ_PRODUCTS = {
    "intellij-2019.2": struct(
        ide = "intellij",
        directory = "intellij_ce_2019_2",
    ),
    "intellij-2019.2-mac": struct(
        ide = "intellij",
        directory = "intellij_ce_2019_2",
    ),
    "intellij-ue-2019.2": struct(
        ide = "intellij-ue",
        directory = "intellij_ue_2019_2",
    ),
    "intellij-ue-2019.2-mac": struct(
        ide = "intellij-ue",
        directory = "intellij_ue_2019_2",
    ),
    "intellij-2019.3": struct(
        ide = "intellij",
        directory = "intellij_ce_2019_3",
    ),
    "intellij-2019.3-mac": struct(
        ide = "intellij",
        directory = "intellij_ce_2019_3",
    ),
    "intellij-ue-2019.3": struct(
        ide = "intellij-ue",
        directory = "intellij_ue_2019_3",
    ),
    "intellij-ue-2019.3-mac": struct(
        ide = "intellij-ue",
        directory = "intellij_ue_2019_3",
    ),
    "android-studio-3.5": struct(
        ide = "android-studio",
        directory = "android_studio_3_5",
    ),
    "android-studio-3.5-mac": struct(
        ide = "android-studio",
        directory = "android_studio_3_5",
    ),
    "android-studio-3.6": struct(
        ide = "android-studio",
        directory = "android_studio_3_6",
    ),
    "android-studio-3.6-mac": struct(
        ide = "android-studio",
        directory = "android_studio_3_6",
    ),
    "android-studio-4.0": struct(
        ide = "android-studio",
        directory = "android_studio_4_0",
    ),
    "clion-2019.2": struct(
        ide = "clion",
        directory = "clion_2019_2",
    ),
    "clion-2019.3": struct(
        ide = "clion",
        directory = "clion_2019_3",
    ),
}

def select_for_plugin_api(params):
    """Selects for a plugin_api.

    Args:
        params: A dict with ij_product -> value.
                You may only include direct ij_products here,
                not indirects (eg. intellij-latest).
    Returns:
        A select statement on all plugin_apis. Unless you include a "default",
        a non-matched plugin_api will result in an error.

    Example:
      java_library(
        name = "foo",
        srcs = select_for_plugin_api({
            "intellij-2016.3.1": [...my intellij 2016.3 sources ....],
            "intellij-2012.2.4": [...my intellij 2016.2 sources ...],
        }),
      )
    """
    for indirect_ij_product in INDIRECT_IJ_PRODUCTS:
        if indirect_ij_product in params:
            error_message = "".join([
                "Do not select on indirect ij_product %s. " % indirect_ij_product,
                "Instead, select on an exact ij_product.",
            ])
            fail(error_message)
    return _do_select_for_plugin_api(params)

def _do_select_for_plugin_api(params):
    """A version of select_for_plugin_api which accepts indirect products."""
    if not params:
        fail("Empty select_for_plugin_api")

    expanded_params = dict(**params)

    # Expand all indirect plugin_apis to point to their
    # corresponding direct plugin_api.
    #
    # {"intellij-2016.3.1": "foo"} ->
    # {"intellij-2016.3.1": "foo", "intellij-latest": "foo"}
    fallback_value = None
    for indirect_ij_product, resolved_plugin_api in INDIRECT_IJ_PRODUCTS.items():
        if resolved_plugin_api in params:
            expanded_params[indirect_ij_product] = params[resolved_plugin_api]
            if not fallback_value:
                fallback_value = params[resolved_plugin_api]
        if indirect_ij_product in params:
            expanded_params[resolved_plugin_api] = params[indirect_ij_product]

    # Map the shorthand ij_products to full config_setting targets.
    # This makes it more convenient so the user doesn't have to
    # fully specify the path to the plugin_apis
    select_params = dict()
    for ij_product, value in expanded_params.items():
        if ij_product == "default":
            select_params["//conditions:default"] = value
        else:
            select_params["//build_support/intellij_platform_sdk:" + ij_product] = value

    return select(
        select_params,
        no_match_error = "define an intellij product version, e.g. --define=ij_product=intellij-latest",
    )

def select_for_ide(intellij = None, intellij_ue = None, android_studio = None, clion = None, default = []):
    """Selects for the supported IDEs.

    Args:
        intellij: Files to use for IntelliJ. If None, will use default.
        intellij_ue: Files to use for IntelliJ UE. If None, will use value chosen for 'intellij'.
        android_studio: Files to use for Android Studio. If None will use default.
        clion: Files to use for CLion. If None will use default.
        default: Files to use for any IDEs not passed.
    Returns:
        A select statement on all plugin_apis to lists of files, sorted into IDEs.

    Example:
      java_library(
        name = "foo",
        srcs = select_for_ide(
            clion = [":cpp_only_sources"],
            default = [":java_only_sources"],
        ),
      )
    """
    intellij = intellij if intellij != None else default
    intellij_ue = intellij_ue if intellij_ue != None else intellij
    android_studio = android_studio if android_studio != None else default
    clion = clion if clion != None else default

    ide_to_value = {
        "intellij": intellij,
        "intellij-ue": intellij_ue,
        "android-studio": android_studio,
        "clion": clion,
    }

    # Map (direct ij_product) -> corresponding ide value
    params = dict()
    for ij_product, value in DIRECT_IJ_PRODUCTS.items():
        params[ij_product] = ide_to_value[value.ide]
    params["default"] = default

    return select_for_plugin_api(params)

def _plugin_api_directory(value):
    return "@" + value.directory + "//"

def select_from_plugin_api_directory(intellij, android_studio, clion, intellij_ue = None):
    """Internal convenience method to generate select statement from the IDE's plugin_api directories."""

    ide_to_value = {
        "intellij": intellij,
        "intellij-ue": intellij_ue if intellij_ue else intellij,
        "android-studio": android_studio,
        "clion": clion,
    }

    # Map (direct ij_product) -> corresponding product directory
    params = dict()
    for ij_product, value in DIRECT_IJ_PRODUCTS.items():
        params[ij_product] = [_plugin_api_directory(value) + item for item in ide_to_value[value.ide]]

    # No ij_product == intellij-latest
    params["default"] = params[INDIRECT_IJ_PRODUCTS["intellij-latest"]]

    return select_for_plugin_api(params)
